## Plan Review — Retarget the bio stream to `root.id` (round 3)

**Files Reviewed:** 1 plan + verified against 7 source/test/spec files
**Risk Level:** 🟢 Low

This is the third review pass. The plan is architecturally sound, every line
reference is accurate against the current code, every predicted test outcome was
traced, and — critically — all three advisory items from plan-review round 2 have
been folded into the plan text. No blocking issues remain.

---

### Round-2 follow-through (all addressed)

1. **Task 3 clock-advance is now mandatory, not parenthetical.** Line 50 states the
   test **MUST** inject a custom `clock` and advance it > 2 s between teardown and
   reopen, with the exact `fakeNow.add(Duration(seconds: 3))` + `async.elapse(...)`
   pattern and a reference to the golden-master reconnect test
   (`biometric_stream_client_test.dart:494-553`). This closes the cooldown gap
   flagged last round.
2. **Class-docstring drift is now an explicit deliverable** (Task 1, line 35):
   correct the `:14-24` comment that falsely claims "current-module-session gating"
   and "Session ended / abandoned clears the ring." Scoped as a one-line hygiene
   fix that does not expand Docs.
3. **Stale note 17 §22 reconciliation is now Task 4** (lines 54-56), documentation-
   only, independent, correctly targeting the falsified "keep the disconnect path
   clearing `_sessionConfirmed` and re-arming on reconnect" clause.

### Verification (all confirmed against code)

- **Line references are exact.** Constructor initializer list
  (`BiometricStreamClient.dart:69-71`), root-id seam no-op (`:29`, `:66`, `:87`,
  `:116`), disconnect case `_sessionConfirmed = false` (`:77-79`), lifecycle
  Started/Resumed set (`:94-101`), Ended/Abandoned clear (`:106-111`), send gate
  (`:121`), `_rootIdSub` cancel in `dispose` (`:132`), encode path (`:210-245`),
  reopen cooldown (`:145-148`) — all match the current file.
- **App.dart wiring is exact.** `BiometricStreamClient(...)` is constructed at
  `:234` **without** `rootIdChanges`; `rootStateChannel` is built earlier at `:225`
  and exposes `rootIdChanges` — so Task 2's one-line addition is valid and ordered.
- **`rootIdChanges` is a seeded, `.distinct()` `String?` stream.** Confirmed
  `SessionRegistry.dart:16` `BehaviorSubject<String?>.seeded(null)` → `.distinct()`
  at `:73`; surfaced via `ModuleStateChannel.rootIdChanges` (`:37`) →
  `RootStateChannel.rootIdChanges` (`:28`). Late subscriber gets the current value.
- **The reconnect hazard is real and grounded.** `SessionRegistry.clear()`'s own
  comment (`:44-46`) documents that a redundant `null → null` is absorbed by
  `.distinct()`; the same absorption applies to the idempotent `root-1 → root-1`
  re-emission on a transient reconnect. `_onRootIdChanged` is therefore not
  re-entered, so nothing re-arms `_sessionConfirmed` — confirming the plan's
  `if (!_rootSourced)` guard on the disconnect clear is a correctness fix, not an
  optimization.
- **All four existing routing tests stay green.** Traced each in
  `biometric_stream_id_routing_test.dart`: root-1 wins over a later
  `ModuleSessionStarted(child-A)` via the `_rootSourced` early-return; child end
  does not clear; `rootIdChanges.add(null)` clears the id and empties the ring while
  the sink stays open so `injectReady` drains nothing; and the pre-root gate holds.
- **The golden-master file stays green.** In legacy mode (`_rootSourced == false`,
  no `rootIdChanges`), `_onLifecycleEvent` still drives the id and the disconnect
  path still clears `_sessionConfirmed`, preserving "drop sendBatch after
  disconnect", resume-reconfirm, cooldown, replay-ring cap, and readiness tests.
- **Task 3's new test is internally consistent.** Traced the reconnect path: send
  under root-1 → `disconnected` tears down the sink but keeps `_sessionConfirmed`
  (root-sourced) → clock +3 s clears the cooldown → `connected` reopens the stream
  → post-reconnect `sendBatch` passes the gate and drains under root-1 on the new
  `injectReady`. The test faithfully reproduces the gap the four existing tests miss.
- **`final bool _rootSourced` in the initializer list is valid Dart** —
  `rootIdChanges` is a constructor parameter in scope there; the plan's warning
  against `late final`/dropping `final` is correct.
- **Phase path is genuinely decoupled** and correctly fenced off as "do not touch";
  `SESSION_NOT_FOUND` needs no code change (already swallowed); proto is unchanged.

### Context Gates

- **Architecture / RULES.md:** ✅ Pass. Dependency is injected via the constructor
  and the client owns its own `_rootIdSub` subscription; App.dart only wires an
  existing infrastructure stream, introducing no new module state.
- **Roadmap:** ✅ Pass. `ROADMAP.md` line 68 ("Retarget the bio stream to
  `root.id`") matches the plan title and scope verbatim; governing spec
  `notes/17-rootchild-bio-to-root.md` is named on that line and is addressed by
  Task 4.
- **Spec tree:** ✅ Pass (previously WARN). The one stale clause — note 17 §22, line
  22, still confirmed stale in the file — is now explicitly reconciled by Task 4,
  so the spec tree will no longer prescribe the reconnect bug this milestone fixes.
- **Skill-context:** No `.ai-factory/skill-context/aif-review/SKILL.md` present —
  no project-specific review overrides to apply.

### Advisory (non-blocking, no plan change required)

- **Sends during the disconnect window in root-sourced mode.** Because
  `_sessionConfirmed` and `_currentSessionId` now survive a disconnect, a
  `sendBatch` arriving while transport is down passes the gate and calls
  `_ensureSinkOpen`, which may attempt `streamData` against a dead channel
  (throttled by the 2 s cooldown). This is self-healing — a failed open lands in
  `catch`/`onError` → `_teardownSink`, samples fall to the replay ring, and the
  next `connected` reopens and drains — and is the intended consequence of "root
  liveness, not transport, is the gate." Worth being aware of during implementation,
  but not a defect and not something the plan needs to change.

### Positive Notes

- The dual-mode (`_rootSourced`) switch remains the sanctioned way to satisfy note
  23's "golden master never edited" constraint while flipping production to
  root-sourcing; the legacy branch exists solely for that never-edited test.
- The plan converted every round-2 advisory into a concrete, scoped task rather than
  leaving them as prose — Task 3's clock requirement and Task 4's spec fix are now
  first-class steps.
- The reconnect hazard, its `.distinct()` root cause, and the exact remedy are
  captured with correct rationale, and Task 3 targets precisely the untested gap.

### Verdict

No blocking correctness, architecture, migration, or security issues. The plan is
implementable as written, will turn the note-23 routing tests green while keeping
the golden master green, adds the missing reconnect regression coverage, and closes
the stale-spec loop. All prior-round recommendations are resolved.

PLAN_REVIEW_PASS
