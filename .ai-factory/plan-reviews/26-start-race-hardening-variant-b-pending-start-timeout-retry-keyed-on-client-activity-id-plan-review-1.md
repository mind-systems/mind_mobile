# Plan Review — Start-race hardening (variant B): pending-start + timeout + retry keyed on `client_activity_id`

**Plan:** `26-start-race-hardening-variant-b-...md`
**Files Reviewed:** 8 production + 2 test-support files, plus roadmap/spec/notes context
**Risk Level:** 🟡 Medium

## Verdict

The plan is well-grounded and technically sound. Every `:NN` anchor it cites in `ModuleStateChannel.dart`, the two adapters, `ModuleStateEvent.dart`, `GlobalListeners.dart`, `KeepAliveCoordinator.dart`, `BiometricStreamClient.dart`, and `App.dart` is **accurate** against the current tree. The pinned constants (5s / max-2-retries / 3s settling) match the contract test's `async.elapse` expectations, and the per-type adopt/pending model correctly greens each RED scenario in `start_race_contract_test.dart` while preserving the GREEN-now guards. Roadmap + spec linkage is correct (Phase 65, note 19).

The issues below are all in the *sequencing and completeness* of the change, not in its direction. None invalidates the approach; the top one must be fixed before implementation.

### Context Gates

- **Roadmap (WARN → resolved):** Plan heading matches the Phase 65 contract line `Start-race hardening (variant B): pending-start + timeout + retry keyed on client_activity_id`, `Spec: .ai-factory/notes/19-rootchild-start-race-hardening.md`. Governing contract: note 24 (concurrency contract) → note 19 (this impl). Aligned. ✅
- **Rules (PASS):** No violation. All state stays command-level in `ModuleStateChannel` (note 25 §Guards honored — pending-start kept out of the FSM). Adapters remain the token minters; no new state added to `App.dart` beyond the stream-wire mirroring the existing `sessionAbandonedStream` pattern (consistent with the "App.dart is infrastructure" rule — this is a channel→UI wire, same shape as the two already there). ✅
- **Architecture (PASS):** Domain/module boundary respected; no domain leak into packages. ✅

## Critical Issues

### 1. Commit 1 (Tasks 1–2) will not compile — `SessionStartFailed` is defined in Commit 2

Task 2 instructs the give-up path to `_events.add(SessionStartFailed(type))`, and Commit Plan puts Tasks 1–2 in **Commit 1**. But the `SessionStartFailed` class — and the two mandatory `case SessionStartFailed():` additions to the exhaustive sealed switches — live in **Task 3 / Commit 2**.

Consequences after Commit 1 in isolation:
- `SessionStartFailed` is an undefined identifier in `ModuleStateChannel.dart` → compile error.
- Even if the class existed, `BiometricStreamClient._onLifecycleEvent` (`:98`) and `KeepAliveCoordinator._onEvent` (`:47`) are **exhaustive switches over the sealed `ModuleStateEvent`** — adding a new subtype without a case is a Dart compile-time error, not a warning.

The plan itself notes "both exhaustive switches must gain the new case in the same commit (compile-ordering, mirrors note 26)" — but then places the *emit site* one commit **earlier** than the class + switch cases. The commit boundary is internally inconsistent.

**Fix:** Move the minimal `SessionStartFailed` event definition **and** both exhaustive-switch case additions into Task 2 (Commit 1), alongside the emit. Leave only the user-facing wiring (adapter reset, `GlobalListeners` stream, `App.dart` wire, l10n) in Task 3 / Commit 2. Commit 1 then compiles standalone.

## Issues

### 2. Adapter reset on `SessionStartFailed` is not type-scoped — resets a healthy concurrent sibling

Task 3 says: "Adapters reset on it so the user can re-tap: extend the `channel.events` listeners … to also reset when `event is SessionStartFailed`." `SessionStartFailed` carries a `type`, but the instruction drops it.

Both adapters subscribe to **all** `channel.events`. In the concurrent case this whole milestone exists to support (SC-1: live breath + live meditation), if **meditation's** start gives up after retries, an unfiltered `event is SessionStartFailed` check would also fire `BreathModuleStateChannel.reset()` — clearing a *live* breath session's `_started` / `_moduleSessionId` / stopwatch, mid-practice. Symmetric for the reverse.

(This differs from the existing `ModuleSessionAbandoned`/`SessionTerminated` resets, which are whole-tree events where resetting both adapters is correct.)

**Fix:** Gate each adapter's reset on its own type, e.g. `event is SessionStartFailed && event.type == ActivityType.breath` (resp. `meditation`).

### 3. `_beginStart` is referenced in Task 4 but never defined; released deferred starts need to become pending

Task 4 resolves a deferred start with "release it via `_beginStart`/`_sendStart`", but no task introduces `_beginStart` — Task 1 introduces only `_sendStart`, which (per Task 2) increments `attempts` and arms the 5s timer but does **not** create/register the `_PendingStart` in `_pendingStarts`.

A deferred-then-released start (INV-11 no-resume case) must enter `_pendingStarts` so its own 5s confirm-timeout + bounded retry apply — otherwise it is sent exactly once and never retried, silently reopening the tap-into-void window on the reconnect path. The contract test only asserts the release *reaches the wire* (`isNotEmpty`), so this gap would pass the test yet violate INV-8 for that start.

**Fix:** Define the release helper (or extend `_sendStart`'s contract) so a released deferred start is registered in `_pendingStarts` before/while sending. Name it once and use it consistently in Task 1's initial send and Task 4's release.

### 4. Offline-carried timer (Task 2) vs settling-window resolution (Task 4) can double-fire on the same token

Task 2: on timeout while transport is **down**, re-arm the 5s timer without consuming a retry. Task 4: at settling-window close (3s), re-send each carried pending whose type didn't re-arrive. After a reconnect, both mechanisms are live — the re-armed 5s timer may fire inside the 3s window (now `isConnected`) *and* the 3s reconcile may re-send. Two `_sendStart` calls for the same token.

This is **dup-safe** (same `client_activity_id` within the ~10s server dedup window → no duplicate child), so it is not a correctness break, but it double-consumes the 3-attempt budget and doubles wire traffic on every offline→reconnect. Worth an explicit guard (e.g. cancel/neutralize the carried pending's own timer while `_settlingActive`, or let the settling window own resolution exclusively) or at minimum a documented note that the interaction is intentional and dedup-covered.

### 5. Check ordering in `start()` — adopt-existing must precede the settling-window defer

Task 1 defines `start()` order as adopt → per-type-pending-guard → send; Task 4 inserts the `_settlingActive` defer. The plan doesn't pin where the defer sits relative to the adopt check. It should sit **after** adopt: if a live same-type child is already present when the tap lands (even during settling), adopt immediately rather than stashing a deferred start that reconcile then has to discard. Minor, but pin it so the implementer doesn't put the settling check first and defer an already-adoptable tap.

## Positive Notes

- **Anchors are exact.** `_isPendingStart` `:44`, the shared start guard `:333`, pending clears `:232-233`/`:242-243`, `_resetWholeTree` `:426-431`, the reconcile window `:145-157`, `takeOverHere` `:324-328`, `dispose` `:441-450`, and all Task 3 anchors verified against the live files.
- **Constants match the executable spec.** 5s / ≤3 attempts / 3s line up precisely with the `async.elapse` steps and `lessThanOrEqualTo(3)` / `greaterThanOrEqualTo(2)` assertions in `start_race_contract_test.dart`. The attempt-counting model (increment on send, give up at `attempts >= 3`) yields exactly 3 wire sends across three 5s windows — matches INV-12.
- **Correctly identifies the real bug.** Dropping the `currentState.status == active` clause from the start guard is precisely what greens INV-10 cross-type and SC-1 concurrent, and `childOfType`-based adopt correctly preserves the INV-10/SC-7 same-type and INV-8 post-confirm guards.
- **First-connect vs reconnect discrimination** via `_lifecycle != disconnected` at `_openSessionStream` top is the right seam and correctly leaves first-connect timing (INV-8/SC-2) untouched.
- **Test-migration discipline** (one-pass audit of the full blast radius, no weakening of the contract test) is explicitly carried from notes 19/20.
- **l10n mechanics are correct:** `sessionMovedToAnotherDevice`/`sessionAbandoned` keys exist in `app_en.arb`; `packages/mind_l10n/l10n.yaml` (`synthetic-package: false`) makes `cd packages/mind_l10n && flutter gen-l10n` the right regeneration step.

## Recommendation

Address Issue 1 (commit resequencing) and Issues 2–3 (type-scoped adapter reset, define the release-into-pending helper) before implementation. Issues 4–5 are clarifications that will otherwise surface in review. The plan's direction, grounding, and test alignment are solid.
