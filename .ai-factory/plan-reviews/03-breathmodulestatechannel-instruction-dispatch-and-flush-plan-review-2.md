# Plan Review: BreathModuleStateChannel — instruction dispatch and flush (Iteration 2)

**Plan file:** `.ai-factory/plans/03-breathmodulestatechannel-instruction-dispatch-and-flush.md`
**Target spec:** `test/BreathModule/breath_module_state_channel_test.dart`
**SUT:** `lib/BreathModule/Core/BreathModuleStateChannel.dart`
**Prior review:** `plan-reviews/03-breathmodulestatechannel-instruction-dispatch-and-flush-plan-review-1.md`

## Risk Level: 🟡 Medium

Iteration 2 addresses **all six** critical issues and **all four** minor issues from review 1 with disciplined rewrites. The "Important behavioural quirks" preface is excellent and prevents the most likely implementer mistakes. However, two test cases in Phase 3 (Task 3 sub-tests 3 and 4) contain assertions that cannot hold given the SUT's actual behaviour, and one test in Phase 1 (sub-test 7) carries a contradictory inline note. These must be fixed before implementation.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** PASS — no concerns; plan only extends an existing test file.
- **Rules (`.ai-factory/RULES.md`):** not present — gate skipped.
- **Roadmap (`.ai-factory/ROADMAP.md`):** WARN — plan still has no linkage to a roadmap milestone. Acceptable for test hardening, but worth noting.

## Resolved from Review 1

- **Issue 1 (unreachable `!_started` branch):** Note 2 in "Important behavioural quirks" explicitly forbids tests claiming to exercise that branch. ✅
- **Issue 2 (first-emission phase-change contamination):** Note 1 documents the quirk and prescribes pre-priming via `ready+pause`. Every Phase 1 multi-emission test now uses the priming pattern. ✅
- **Issue 3 (buffer test unverifiable):** Phase 2 Test 1 is explicitly weakened to "no immediate dispatch" and defers buffer proof to Test 2. ✅
- **Issue 4 (Task 3 Test 1 unverifiable):** Now includes the flush-and-assert step with `'sid-B'`. ✅
- **Issue 5 (Task 4 duplicates):** Task 4 now contains only the single channel-state-subscription cancel test, with an explicit note that the four duplicates are covered by Phase 7. ✅
- **Issue 6 (Task 4 sub-test 5 contradictory verification):** Rewritten to use the public `target.moduleSessionId` getter rather than a "still-alive path". ✅
- **Issue 7 (start side effects post-reset):** Note 3 spells out the `startCalls.length == 2` tolerance; each affected test in Task 3 explicitly says "Tolerate `f.channel.startCalls.length == 2`". ✅
- **Issue 8 (`currentIntervalMs: -1` coverage):** New Phase 1 case explicitly asserts pass-through of `-1`. ✅
- **Issue 10 (simultaneous phase + exerciseIndex change):** New Phase 1 case `'should call instructionStream.sendSample exactly once when phase and exerciseIndex change simultaneously'`. ✅

## Critical Issues

### 1. Task 3 sub-tests 3 and 4 — assertions cannot hold without re-seeding `ModuleState` after reset

**Sub-test 3** (`should clear _previousPhase on reset`) and **sub-test 4** (`should clear _previousExerciseIndex on reset`) both contain this sequence:

> Setup: seed ModuleState; emit `ready+pause` (`phase=inhale`); emit `ready+breath` (`phase=exhale`) → 1st dispatch; call `reset()`; emit `ready+pause` (`phase=inhale`); emit `ready+breath` (`phase=exhale`) → expected 2nd dispatch. Assert `sendSampleCalls.length == 2`.

This will fail. `reset()` sets `_moduleSessionId = null` (`BreathModuleStateChannel.dart:111`). After reset, the post-reset `ready+breath` emission reaches `_handleInstruction` with `sessionId == null` and takes the buffering branch (`BreathModuleStateChannel.dart:96–99`):

```dart
if (sessionId == null) {
  _pendingInstruction = state;
  return;
}
```

So no second `sendSample` fires — `sendSampleCalls.length` remains **1**, not 2. The asserted `_previousPhase`-cleared contract is genuinely worth testing, but the test as written conflates "previousPhase cleared" with "moduleSessionId cleared" and the latter dominates.

**Fix:** push a new `ModuleState(moduleSessionId: 'sid', status: active)` onto `f.channel.stateController` after `reset()` (and before the post-reset emissions, or immediately after them to flush the pending). Two equivalent options:

- **Option A (re-seed before post-reset emissions):**
  ```dart
  f.target.reset();
  f.channel.stateController.add(const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active));
  await Future<void>.delayed(Duration.zero);
  // ...then prime via ready+pause and emit ready+breath as planned
  ```
  Post-reset emissions then dispatch directly (sessionId present) → `sendSampleCalls.length == 2`.

- **Option B (re-seed after the post-reset emissions, prove via flush):**
  ```dart
  // ...emit post-reset ready+pause and ready+breath (these buffer)
  f.channel.stateController.add(const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active));
  await Future<void>.delayed(Duration.zero);
  ```
  The buffered phase change flushes via `_flushPending`, yielding the 2nd entry.

Option A is cleaner because it isolates the `_previousPhase`-cleared contract from the `_pendingInstruction` flow. Use Option A and explicitly note: "the re-seed restores `_moduleSessionId` because `reset()` cleared it; this test isolates `_previousPhase`."

The same fix applies verbatim to sub-test 4 (`_previousExerciseIndex`).

### 2. Phase 1 sub-test 7 — inline "will also dispatch once" comment is incorrect

> *"prime via `ready+pause` (`phase=inhale, exerciseIndex=0`); emit `ready+breath` (`phase=inhale, exerciseIndex=0`) **to satisfy the lifecycle start (note: this will also dispatch once)**; then emit `ready+rest` (`phase=exhale, currentIntervalMs=6000`). Assert the **last** entry in `sendSampleCalls` is `('sid', 'exhale', 6000)`."*

The parenthetical is wrong. After the priming `ready+pause(inhale, 0)` emission, `_previousPhase=inhale` and `_previousExerciseIndex=0` are set unconditionally at the bottom of `_onState` (`BreathModuleStateChannel.dart:48–50`). The next `ready+breath(inhale, 0)` therefore evaluates `phaseChanged = (inhale != inhale) || (0 != 0) = false`, and `_handleInstruction` returns at line 94. **No dispatch fires** on that emission.

Only the final `ready+rest(exhale, 0)` actually dispatches, yielding `sendSampleCalls.length == 1` and `sendSampleCalls.last == ('sid', 'exhale', 6000)`.

The assertion `sendSampleCalls.last == ('sid', 'exhale', 6000)` is still satisfied, so the test passes for the right reason. But the misleading note will trip up an implementer who reads it as "expect length 2" or who tries to assert anything about the intermediate state. Rewrite the parenthetical to: "(note: this `ready+breath` emission starts the lifecycle but does **not** dispatch, because `_previousPhase` was primed to `inhale` by the prior pause)".

## Minor Issues

### 3. Phase 1 sub-test 6 (`_ended` guard) — implementation hint could be sharper

> *"drive lifecycle through `breath → complete` so `_ended=true`; then emit a `ready+breath` state with a different phase. Assert no additional `sendSampleCalls` beyond whatever was dispatched before complete (record the count just before `complete` and assert it is unchanged after the post-complete emission)."*

The first `ready+breath` is itself the first emission and will dispatch once (`_previousPhase` is initially null). Then `complete` lifecycle-only (no dispatch — `!isActive`). Then post-complete `ready+breath(differentPhase)` is filtered by `_ended` guard.

This works, but the "record the count just before complete" instruction is unclear. Concretely: assert `sendSampleCalls.length == 1` after the initial `ready+breath`, then assert it is **still** `1` after the post-complete emission. Add this as an explicit assertion sequence so the implementer doesn't have to derive it.

Also note the lifecycle path after `complete → ready+breath`:
- `_previousStatus = complete` (set by the complete emission).
- New emission has `status = breath`. None of the four lifecycle branches match (`wasPaused=false`, `wasActive=false`, not `complete`). Lifecycle does nothing — no spurious `start` call. This is worth noting in the plan because the same scenario in Task 3 tests explicitly tolerates `startCalls.length == 2`; here it must stay `1`.

### 4. Phase 2 sub-test 5 (`overwrite the pending instruction`) — depends on lifecycle short-circuit, worth documenting

The test emits two consecutive `ready+breath` states. The second emission's lifecycle hits `if (status == _previousStatus) return;` at the top of `_handleLifecycle` and short-circuits before any handling — but `_handleInstruction` is still called from `_onState` *after* `_handleLifecycle` returns, so the second emission overwrites `_pendingInstruction`. This is the intended behaviour, but the plan doesn't explicitly call it out. A one-line note ("the second breath state short-circuits in lifecycle but reaches `_handleInstruction`") would prevent confusion.

### 5. Task 4 — `await Future<void>.delayed(Duration.zero)` after `add()` post-dispose

The test description says "push ModuleState ... onto `f.channel.stateController`; await microtask." The standard pattern in this file is `await Future<void>.delayed(Duration.zero)` (used throughout). Recommend explicitly saying "await `Future<void>.delayed(Duration.zero)`" to match the existing convention rather than the loose "await microtask" phrasing — broadcast stream delivery is microtask-scheduled, and the delay-zero idiom is what every other test uses.

### 6. ModuleState construction — `isPaused` default

All test setups construct `ModuleState` with only `moduleSessionId` and `status`. The class has a third optional field `isPaused` with default `false` (`lib/Core/Grpc/ModuleState.dart:8`). Nothing in the SUT reads `isPaused`, so this is fine — but adding a one-line note ("`isPaused` is not read by `BreathModuleStateChannel`; omit from constructors") would prevent the implementer from second-guessing.

## Positive Notes

- **Excellent preface.** "Important behavioural quirks the implementer MUST account for" is rare in plan files and prevents the entire class of mistake that contaminated review 1.
- **Test 5 of Task 3** (channel.state subscription alive across reset) **correctly** re-pushes a ModuleState after reset because the subscription survival is itself the contract. The implementer should look at this test as the model for fixing sub-tests 3 and 4.
- **Phase 2 sub-test 6** (non-ready emission between buffering and flush) is a sharp test targeting a real subtle ordering bug — the kind of case implementers usually miss.
- **`currentIntervalMs: -1` test** is a textbook example of how to anchor a test against the real-world initial state instead of a synthetic default.
- **Task 4 cleanup** — explicitly listing the existing Phase 7 line numbers that already cover the dispose contract avoids accidental duplication.

## Summary

Iteration 2 is a substantial improvement and resolves every issue from review 1. Before implementation can proceed:

1. **Fix Issue 1:** Task 3 sub-tests 3 and 4 must re-push a `ModuleState` after `reset()` (Option A recommended), or they will fail at `sendSampleCalls.length == 2` because `_moduleSessionId` is cleared by reset and the post-reset emission buffers instead of dispatching.
2. **Fix Issue 2:** Rewrite the inline parenthetical in Phase 1 sub-test 7 — the intermediate `ready+breath(inhale, 0)` does **not** dispatch (phase matches primed value).

Issues 3–6 are non-blocking polish that will make the implementer's job easier.

After Issues 1 and 2 are addressed, the plan is ready for implementation.
