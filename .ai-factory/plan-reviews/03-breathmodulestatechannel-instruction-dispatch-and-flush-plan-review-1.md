# Plan Review: BreathModuleStateChannel — instruction dispatch and flush

**Plan file:** `.ai-factory/plans/03-breathmodulestatechannel-instruction-dispatch-and-flush.md`
**Target spec:** `test/BreathModule/breath_module_state_channel_test.dart`
**SUT:** `lib/BreathModule/Core/BreathModuleStateChannel.dart`

## Risk Level: 🟡 Medium

The plan correctly identifies the three new test surfaces (`_handleInstruction`, `_flushPending`, instruction-related reset/dispose bookkeeping) and reuses the established scaffolding. However, several test descriptions either don't actually exercise the guard they claim to test, are unverifiable as written, or duplicate existing cases already in the file.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** WARN — no concerns. Plan only adds tests to existing module under `test/BreathModule/`, no boundary violations.
- **Rules (`.ai-factory/RULES.md`):** not present — gate skipped.
- **Roadmap (`.ai-factory/ROADMAP.md`):** WARN — plan does not link to a milestone; for test-coverage hardening this is acceptable but worth noting.

## Critical Issues

### 1. Phase 1 — "session has not started" test exercises the wrong guard

> *"should not call instructionStream.sendSample when a phase change occurs before the session has started (status=breath but loadState filters or first lifecycle has not flipped `_started`) — drive a phase change while a `moduleSessionId` is already present but no active lifecycle has run (e.g. by emitting a non-ready state first, then a ready pause); assert `sendSampleCalls` is empty"*

Under the current SUT (`_onState` runs `_handleLifecycle` **before** `_handleInstruction` in the same call), the `!_started` guard inside `_handleInstruction` is effectively unreachable in normal flow: any `ready+active` state that reaches `_handleInstruction` has already flipped `_started=true` two lines earlier. The proposed setup — non-ready breath, then ready pause — never reaches the `!_started` check because the second emission is `pause`, so `_handleInstruction` returns at the `!isActive` check first. The assertion will pass for the wrong reason.

**Recommendation:** either (a) drop this case as a non-reachable defensive guard, (b) reword the test name to reflect that it asserts non-dispatch on a `pause` emission with no prior active state, or (c) restate intent as "documents that no instruction is dispatched until lifecycle has flipped `_started`" and accept that it shares its assertion with the `!isActive` guard. Don't claim it exercises `!_started`.

### 2. Phase 1 — first-emission phase-change is implicit and contaminates assertions

`_previousPhase` and `_previousExerciseIndex` are both initialized to `null`. The very first `ready+active` emission therefore triggers `phaseChanged=true` because `inhale != null` (and `0 != null`). Tests of the form "push ModuleState → push first breath state → assert sendSample called once" will pass, but it is not actually verifying "phase changes" — it is verifying "first dispatch since construction".

For tests that want to assert a **subsequent** phase change (e.g. Phase 1 cases 1 and 2: "phase changes while status=breath" and "exerciseIndex changes while phase stays the same"), the implementer needs **two** active emissions and will then see **two** `sendSampleCalls`:
- Emission A: phase=inhale, exerciseIndex=0 → triggers `phaseChange` (null→inhale) → 1st sendSample
- Emission B: phase=exhale, exerciseIndex=0 → triggers `phaseChange` (inhale→exhale) → 2nd sendSample

The plan's note "use distinct `currentIntervalMs` per emission" helps disambiguate, but the test description needs to acknowledge that two calls are expected and that the **second** one is the phase-change-under-test. Otherwise the implementer will likely write `expect(sendSampleCalls, hasLength(1))` and fail.

**Recommendation:** for each "phase changes" test in Phase 1, explicitly state in the test case description (or in the Notes section) the expected call count (≥2) and which emission corresponds to which entry in `sendSampleCalls`. Or pre-prime by pushing a `pause` first — but `pause` won't update `_previousPhase` because `_handleInstruction` returns at `!isActive` before the assignment? Wait — `_previousPhase` is updated unconditionally in `_onState` after both handlers run, even on a `pause` state. So a `ready+pause` emission with phase=inhale **does** prime `_previousPhase=inhale` without dispatching, because `_handleInstruction` returns at `!isActive`. This is a clean way to suppress the spurious first-emission call.

### 3. Phase 2 Test 1 — "store the state for later flush" is not verifiable in isolation

> *"should not call instructionStream.sendSample when a phase change occurs while moduleSessionId is null, but instead store the state for later flush"*

The buffering is observable only by *later* pushing a `ModuleState` with a non-null `moduleSessionId` and asserting `sendSample` fires with the buffered args. Without that second step, the test can only assert `sendSampleCalls` is empty — which doesn't distinguish "buffered" from "silently dropped". This overlaps with Phase 2 Test 2 ("flushes exactly once when ModuleState arrives"). 

**Recommendation:** either explicitly couple Test 1 with a flush-and-assert step (merging into Test 2), or restate Test 1's assertion as "sendSample is not called immediately" and leave buffering proof to Test 2.

### 4. Phase 3 Task 3 Test 1 — same unverifiability issue

> *"should clear moduleSessionId on reset, verified by emitting a phase change after reset (with no new ModuleState) and observing the state is buffered rather than sent"*

Same flaw as above. "With no new ModuleState" means there is no way to prove the state was buffered — only that no dispatch occurred. To prove buffering, push a `ModuleState` afterwards and assert sendSample fires. Otherwise reword to "no dispatch occurs after reset until a new ModuleState arrives".

**Recommendation:** add a final `f.channel.stateController.add(ModuleState(moduleSessionId: 'X', status: active))` step and assert sendSample fires with the buffered phase/interval. This becomes a stronger test that also covers the moduleSessionId-clear contract.

### 5. Phase 3 Task 4 — sub-tests 1, 2, 3 duplicate existing Phase 7 coverage

The current file's `Phase 7: dispose() / stop()` group already covers:
- "should call channel.stop exactly once when dispose is invoked while the session is started and not yet ended" (line 597) → **same as Task 4 sub-test 1**
- "should not call channel.stop when dispose is invoked before any state has been emitted" / "after only non-ready emissions" (lines 571, 582) → **same as Task 4 sub-test 2**
- "should not call channel.stop when dispose is invoked after the session has already completed" (line 622) → **same as Task 4 sub-test 3**
- "should not dispatch any further lifecycle calls when state emissions arrive after dispose has run" (line 636) → **same as Task 4 sub-test 4**

Only Task 4 sub-test 5 (cancellation of `_channelSub`) is genuinely new. The plan's instruction "Add the three new groups after the existing `reset()` group; keep the existing groups untouched" combined with these duplicates implies the new group will silently repeat existing assertions.

**Recommendation:** drop sub-tests 1–4 of Task 4 (or explicitly note them as redundant and skip). Keep only sub-test 5, and either fold it into Phase 7 or create a small `dispose() — subscription bookkeeping` group containing just this one case. Optionally add the channel-state-subscription-cancel test using `target.moduleSessionId` getter (see issue 6).

### 6. Phase 3 Task 4 sub-test 5 — verification path is contradictory

> *"should cancel the channel.state subscription on dispose, verified by emitting a ModuleState on the fake channel after dispose and observing moduleSessionId is not updated (no flush, no instruction dispatch on a subsequent phase change driven through any still-alive path)"*

After `dispose()`, both `_stateSub` and `_channelSub` are cancelled, so there is no "still-alive path" through which a subsequent phase change could be driven. The clean assertion is: push `ModuleState(moduleSessionId: 'X')` post-dispose, then read `target.moduleSessionId` via the public getter and assert it is **still null** (or whatever its pre-dispose value was). Drop the "no instruction dispatch on a subsequent phase change" clause — it requires `_stateSub` to be alive, which contradicts the test's own premise.

**Recommendation:** rewrite as: "after dispose, pushing a ModuleState with a non-null moduleSessionId on `f.channel.stateController` does not update `target.moduleSessionId`". This directly proves `_channelSub.cancel()` was called.

## Minor Issues

### 7. Task 3 sub-test 5 — possible side effects from post-reset `start`

> *"should keep the channel.state subscription alive across reset, verified by emitting a new ModuleState after reset and observing the updated moduleSessionId is used on the next phase-change instruction dispatch"*

Post-reset `_started=false`. The next breath state emission flows through `_handleLifecycle` and calls `channel.start(...)` again. The test should explicitly tolerate `f.channel.startCalls.length == 2` (similar to the existing reset tests at lines 658, 678). Not a blocker but worth noting in the test case description so the implementer doesn't accidentally assert `startCalls.length == 1`.

### 8. `_state()` helper default `currentIntervalMs: 4000`

The existing helper has a comment flagging that the real initial state uses `-1`, and positive defaults may mask off-by-one bugs. The plan acknowledges this implicitly by saying "use distinct `currentIntervalMs` per emission". Consider one explicit test that exercises `currentIntervalMs: -1` (the real initial value) to confirm the dispatched payload carries `-1` through unchanged — at the moment nothing in the plan covers this real-world edge case.

### 9. `ModuleStateStatus` field on ModuleState used in Notes — verify shape

The notes example uses `ModuleStateStatus.active`. Confirmed against `lib/Core/Grpc/ModuleState.dart`: the enum is `{ idle, active }` and `ModuleState` requires `moduleSessionId` and `status` (with optional `isPaused`). The example is correct. No issue — just confirming.

### 10. Missing case: instruction dispatch when only `exerciseIndex` and `phase` change simultaneously

Phase 1 covers "phase changes alone" and "exerciseIndex changes alone" but does not assert that simultaneous change still produces exactly one sendSample (not two). Cheap addition; matters if anyone later refactors `phaseChanged` into two separate conditions.

## Positive Notes

- Plan correctly preserves existing tests and appends new groups, matching the documented file structure.
- Reuses `_FakeChannel`, `_FakeInstructionStream`, `_state(...)`, and `_make(...)` — no duplicate scaffolding.
- Note about distinct `currentIntervalMs` values to disambiguate buffered-vs-direct dispatch is good engineering.
- The flush-overwrite case (Phase 2 case 5) and the "buffered state survives intervening non-ready emissions" case (Phase 2 case 6) are well-targeted at real concurrency bugs.
- Task 3 cases 3 and 4 (`_previousPhase` / `_previousExerciseIndex` cleared on reset) cleverly verify private-field reset through observable behaviour (a same-phase emission post-reset re-triggers dispatch). Good design.
- Plan correctly identifies that subscriptions stay alive across `reset()` but are cancelled on `dispose()`.

## Summary

The plan's structure is sound and the test surfaces are well-chosen, but **before implementation can proceed**, the following must be resolved:

1. Fix Issue 1: drop or reword the unreachable `!_started` test.
2. Fix Issue 2: account for the first-emission phase-change side effect in every Phase 1 test that involves two emissions (either via expected-count adjustment, or by pre-priming with a `pause` state).
3. Fix Issue 3 & 4: couple buffering tests with a flush step, or weaken the assertion to "no immediate dispatch".
4. Fix Issue 5: drop the 4 duplicate dispose() tests in Task 4; keep only the channel.state-subscription-cancel case.
5. Fix Issue 6: rewrite Task 4 sub-test 5 to use the `moduleSessionId` getter rather than a contradictory "subsequent phase change" path.

After these revisions, the plan is ready for implementation.
