# Plan Review: Reconnect via `root.id` header + abandoned/reconcile handling

**Plan:** `.ai-factory/plans/25-reconnect-via-root-id-header-abandoned-reconcile-handling.md`
**Files Reviewed:** plan + `ModuleStateChannel.dart`, `ConnectionLifecycle.dart`, `SessionRegistry.dart`, `ModuleStateEvent.dart`, `RootStateChannel.dart`, `reconnect_eviction_contract_test.dart`, `reconnect_concurrency_harness.dart`, `module_state_channel_test.dart`, governing spec `notes/20-rootchild-reconnect-header-abandoned.md`
**Risk Level:** 🟡 Medium — the plan is well-grounded and its line references are accurate, but one localized gap will leave a must-pass contract test (INV-3) red, and one guard-placement ambiguity can self-block the takeover.

## Context Gates
- **ROADMAP.md:** WARN-clear. Milestone line 91 ("Reconnect via `root.id` header + abandoned/reconcile handling") matches the plan heading; the plan correctly targets its `Spec:` note 20 and the governing FSM/event refactor notes 25/26. No linkage gap.
- **Governing spec (note 20):** Plan faithfully mirrors §30–42 (header→`root.id`, SUPERSEDED→yield classification, yielded refuses reopen, whole-tree reset emitters, reconcile-by-arrival, comprehensive one-pass test migration). One divergence — see Critical Issue 1.
- **ARCHITECTURE.md / RULES.md:** No conflict. The three RULES.md conventions (stateless module Services, no module state in App.dart, constructor DI) do not touch this change — it is confined to `lib/Core/Grpc/`. No architectural boundary crossed.
- **Line-number pins:** Verified accurate against the current tree — `_openSessionStream:109-155`, header `:112-116`, `sessionError:129-134`, `onError:139-145`, `onDone:146-152`, connected/disconnected `:89-99`, UNSPECIFIED `:205-211`, `_handleRootFrame:244-253`, `_reset:346-352`, `dispose:356-364`; test `:449-451`/`:531-533`/`:815`, INV-3 skip `:317`, dynamic call `:301`. All correct.
- **No migration / proto change:** Pure Dart gRPC logic on existing statuses and the existing `CONNECTION_SUPERSEDED` string; no Drift schema or `.proto` touched. Correct — no migration needed.

## Critical Issues

### 1. The yield/takeover path never resets the channel's own registry + single-state → INV-3 stays red

This is the central defect. INV-3 (`reconnect_eviction_contract_test.dart:281-317`, un-skipped by **Task 8**) drives, in order:
`root-1` ROOT ACTIVE → `breath-1` child ACTIVE → SUPERSEDED → close → `takeOverHere()` → `root-3` ROOT frame, then asserts:

```dart
expect(f.channel.currentState.status, ModuleStateStatus.idle);   // :308
expect(f.channel.childOfType(ActivityType.breath), isNull);      // :311
```

Trace the plan as written:
- `breath-1` ACTIVE sets the single-state to `active` (`ModuleStateChannel.dart:181-188`) and upserts `breath-1` into the registry.
- SUPERSEDED + close → **Task 3** transitions `→ yielded`, emits `SessionTerminated(movedToAnotherDevice)`, and — per its own text ("do not reset state here") — leaves the registry (`{root-1, breath-1}`) and single-state (`active`) untouched.
- **Task 4** `takeOverHere()` only clears `_supersededOnThisStream` and calls `_openSessionStream()`. It does not clear the registry or reset the single-state.
- `_openSessionStream()` runs **Task 7** reconcile: it snapshots `{breath-1}` and **keeps** those entries alive until the 3s settling window closes. The test never elapses that window.
- `root-3` arrives via `_handleRootFrame`, which touches only the registry, never the single-state.

Result at the assertions: `currentState.status == active` (fails `:308`) and `childOfType(breath) == breath-1` (fails `:311`). Task 8's "green the suite" cannot succeed.

The consumers the plan says to leave alone do **not** cover this: `BreathModuleStateChannel:53` resets its *own* state on `SessionTerminated`, but nothing resets `ModuleStateChannel`'s registry or `_state`. (Verified.)

Spec note 20 confirms the intended behavior the plan omits: §13/§37 — "on an explicit takeover it receives a RESUMED root frame with no child frames and starts fresh … do not expect the old children back"; note 26 groups `movedToAnotherDevice` with `abandoned`/`rootDeath` as a *whole-tree termination reason*. So the eviction path should perform the **same whole-tree reset Task 5 performs** for its sibling reasons (clear registry + single-state → `initial()` + clear pending guards), differing only in the emitted reason.

The plan is internally inconsistent here: **Task 5** clears registry + single-state + pending guards + emits `SessionTerminated` for `abandoned`/`rootDeath`, but **Task 3** emits `SessionTerminated(movedToAnotherDevice)` with none of that reset. That asymmetry is the bug.

**Fix:** On the SUPERSEDED yield transition (Task 3) — or, if the UX wants the evicted session to remain visible while `yielded`, inside `takeOverHere()` before the reopen — perform the whole-tree reset: `_registry.clear()`, `_state.add(ModuleState.initial())`, clear `_isPendingStart`/`_isPendingPause`. Resetting on yield is the cleaner choice: it makes the `movedToAnotherDevice` path symmetric with Task 5, and once the registry is empty the Task 7 reconcile snapshot at takeover reopen is empty, so `childOfType(breath)` is `null` immediately (no dependence on the 3s window). Task 3's directive "do not reset state here" should be narrowed to "do not `disconnect()`/`scheduleReconnect()` here" — the whole-tree reset is exactly what is missing.

### 2. Yielded-reopen guard placement can self-block `takeOverHere()`

**Task 4** offers two placements for the reopen guard: "at the top of `_openSessionStream` (or the connected handler at `:91-92`)". These are **not** interchangeable given how `takeOverHere()` is specified.

`takeOverHere()` is defined as "clear `_supersededOnThisStream`, then call `_openSessionStream()`" — it does **not** transition out of `yielded` first, and `_openSessionStream`'s own `_transition(opening)` is at `:110` (the *first* line, so a guard "at the top" precedes it). If the guard is placed at the top of `_openSessionStream` as `if (_lifecycle == yielded) return;`, then `takeOverHere()` — calling `_openSessionStream()` while `_lifecycle` is still `yielded` — hits the guard and returns without opening. INV-3's `expect(f.service.calls.length, callBaseline + 1)` (`:304`) then fails, and INV-2/SC-6 passes only vacuously.

Spec note 20 §37 frames `takeOverHere()` as *the* `yielded → opening` transition, i.e. the one caller allowed to leave `yielded`; §36 says the guard exists to make *connection-manager* reopens (connectivity/app-resume/auth) inert. That points to guarding the **connected handler** (`:91-92`), so `takeOverHere()`'s direct `_openSessionStream()` call bypasses it. 

**Fix:** Pin the guard to the `connected` handler (`case connected: if (_lifecycle == yielded) break;`), **or** require `takeOverHere()` to transition `yielded → opening` before invoking `_openSessionStream()`. Remove the "at the top of `_openSessionStream`" option, which combined with the literal Task 4 body produces a broken takeover.

## Minor Notes (non-blocking)

- **Task 7 — `childIds` should exclude the root.** The plan adds `childIds`/`removeById` to `SessionRegistry` and snapshots "child ids". Ensure `childIds` filters out the `ActivityType.root` entry (mirror the `childOfType` guard at `SessionRegistry.dart:62-68`); otherwise a stale root id lands in the snapshot. Harmless (the root is dropped separately and a re-minted root carries a new id), but cleaner to exclude it. Also ensure `removeById` calls `_notify()` so `rootId` (a `BehaviorSubject.value`) updates synchronously — Task 1 relies on the drop being observable the moment reconcile runs.
- **Task 7 — settling `Timer` under `fakeAsync`.** INV-4 and INV-6 dispose without elapsing the 3s window, so the pending `Timer` must be cancelled in `dispose()` (`:356-364`) or `fakeAsync` throws on a pending timer. The plan already requires this — call it out explicitly for the implementer, and note the timer is armed on *every* `_openSessionStream` (including first connect, where the snapshot is empty and eviction is a no-op).
- **Task 3 flag lifetime.** `_supersededOnThisStream` reset-on-`opening` is correct, but confirm it is also cleared in `_reset` (Task 4 says so) — an evicted-then-logged-out-then-relogged device must not carry the flag into a fresh stream. The plan covers this; keep it in the same commit as Task 3/4.
- **Task 2 ordering dependency.** The rewritten header assertion (`metadata['module-session-id'] == 'root-1'`) depends on Task 1 reading `rootId` into a local *before* Task 7's reconcile drops the root. Since Task 2 ships in Commit 1 (before Task 7), it will pass at that point regardless; but once Task 7 lands, the "read-before-drop" ordering (Task 1) is what keeps it green. The plan sequences this correctly — just verify the local-read is genuinely before the `removeById(rootId)` when Task 7 is implemented.

## Positive Notes
- **Blast-radius audit is complete and one-pass**, exactly as the rescue fix (note 20 §18/§42) mandates. Every invalidated assertion is named with a line number: header `:449-451`/`:531-533` (Task 2), UNSPECIFIED-emptiness `:815` (Task 6), INV-3 skip `:317` + dynamic dispatch `:301` (Task 8). The Group 11 UNSPECIFIED test (`:1240-1269`) and the root-terminal handling correctly need no migration — verified: the former asserts only state/`rootId` (no event listener), and no test drives a *root-level* terminal frame, so Task 5's `_handleRootFrame` change has no blast radius in `module_state_channel_test.dart`.
- **FSM-first discipline honored.** Every state change is expressed as a `ConnectionLifecycle` transition or a `SessionTerminated(reason)` emission — no reintroduced `_yielded`/`_supersededSeen` free booleans (note 20 §49). `_supersededOnThisStream` is correctly scoped as a per-stream transition guard reset on `opening`, not a cross-handler latch.
- **Reconcile-by-arrival design matches the spec precisely** — read-root-before-drop, drop-root-immediately (INV-4), snapshot/arm/evict-silent (INV-5/SC-3), tolerate one-or-many collapsed frames, and an explicitly clean seam for note 19's start-race to anchor to without implementing retry here.
- **Correct restraint on the dormant consumers** — the plan drives them via the emitter rather than touching them, and leaves `is_paused` trusted-from-RESUMED (INV-7 guard) and the onError/bare-close paths (INV-1/SC-5) untouched.
- **Commit plan is coherent** — each commit pairs the production change with its migrated assertions, so no commit lands red.

## Verdict
Two must-fix items before implementation: (1) add the whole-tree reset to the `movedToAnotherDevice` yield/takeover path so INV-3 can go green, and (2) pin the reopen guard to the connected handler (or make `takeOverHere` leave `yielded` first) so the takeover is not self-blocked. Both are small, localized additions to the existing task text; the plan's structure, sequencing, and grounding are otherwise sound.
