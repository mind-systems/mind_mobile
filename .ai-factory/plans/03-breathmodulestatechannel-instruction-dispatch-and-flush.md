# Test Plan: BreathModuleStateChannel — instruction dispatch and flush

## Context
Extends the existing `breath_module_state_channel_test.dart` (lifecycle + reset/dispose already covered) with three new groups that exercise the instruction-stream code paths inside `BreathModuleStateChannel`: `_handleInstruction`, `_flushPending`, and the parts of `reset()`/`dispose()` related to instruction state, the new private fields, and subscription bookkeeping.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`/usr/local/bin/flutter test test/BreathModule/breath_module_state_channel_test.dart`

## Target Spec File
`test/BreathModule/breath_module_state_channel_test.dart`

## Notes for the implementer

- Use the existing `_FakeChannel`, `_FakeInstructionStream`, `_state(...)`, and `_make(...)` helpers — do not introduce parallel scaffolding.
- To make `moduleSessionId` available before/after a phase change, push onto the existing fake controller, e.g.:
  ```dart
  f.channel.stateController.add(
    const ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active),
  );
  await Future<void>.delayed(Duration.zero);
  ```
- Use distinct `currentIntervalMs` per emission (e.g. `4000`, `5000`) so that flushed instruction arguments can be unambiguously matched to the originating state.
- Add the three new groups **after** the existing `reset()` group; keep the existing groups untouched.

### Important behavioural quirks the implementer MUST account for

1. **First-emission phase change is implicit.**
   Both `_previousPhase` and `_previousExerciseIndex` are initialized to `null`. The first `ready+active` emission therefore always satisfies `phaseChanged=true` (`inhale != null`, `0 != null`) and triggers a `sendSample` call (provided `_started` and `moduleSessionId` are set). To assert a **subsequent** phase change in isolation, **pre-prime** `_previousPhase` / `_previousExerciseIndex` by first emitting a `ready+pause` state with the desired starting phase/exerciseIndex. Note that `_handleInstruction` returns at the `!isActive` guard for `pause`, so no dispatch occurs — but `_previousPhase` and `_previousExerciseIndex` are still updated at the end of `_onState`. Alternatively, accept that two `sendSampleCalls` entries will exist and assert against the **last** one.

2. **Lifecycle runs before instruction.**
   In `_onState`, `_handleLifecycle` is called before `_handleInstruction` in the same invocation. The `!_started` guard inside `_handleInstruction` is effectively unreachable in normal flow because any `ready+active` emission flips `_started=true` before instruction handling. Do **not** write tests that claim to exercise the `!_started` branch directly.

3. **Post-reset re-start fires `channel.start` again.**
   After `reset()`, `_started=false`, so the next active emission will call `channel.start(...)` a second time. Tests that emit an active state post-reset must tolerate `f.channel.startCalls.length == 2` (consistent with existing reset tests at lines 658 and 678).

4. **`reset()` clears `_moduleSessionId`.**
   `reset()` sets `_moduleSessionId = null` (`BreathModuleStateChannel.dart:111`). After reset, any phase-change emission reaches `_handleInstruction` with `sessionId == null` and takes the buffering branch — no immediate dispatch fires. Tests that want to assert "previous-phase / previous-exerciseIndex cleared on reset" via a post-reset **direct dispatch** **must re-push a `ModuleState(moduleSessionId: 'sid', status: active)` onto `f.channel.stateController` after `reset()`** (and `await Future<void>.delayed(Duration.zero)`) to restore `_moduleSessionId` **before** emitting post-reset `BreathSessionState`. Otherwise the assertion conflates "previousPhase cleared" with "moduleSessionId cleared" and the latter dominates. (Test 5 in Task 3 is the model for this re-seed pattern — it re-pushes ModuleState because the subscription-survival contract demands it; Tasks 3 sub-tests 3 and 4 use the same pattern for the same reason.)

5. **`_handleLifecycle` short-circuits on same `_previousStatus`, but `_handleInstruction` still runs.**
   At the top of `_handleLifecycle`, `if (status == _previousStatus) return;` short-circuits before any lifecycle handling — but `_handleInstruction` is invoked from `_onState` **after** `_handleLifecycle` returns, regardless of whether lifecycle short-circuited. Two consecutive emissions with the same status (e.g. two `ready+breath` in a row) will therefore still reach `_handleInstruction` and can overwrite `_pendingInstruction`.

6. **`ModuleState.isPaused` is not read by the SUT.**
   `ModuleState` has an optional `isPaused` field with default `false` (`lib/Core/Grpc/ModuleState.dart:8`). `BreathModuleStateChannel` does not read it. Construct `ModuleState` with only `moduleSessionId` and `status` in all tests; omit `isPaused`.

7. **Microtask flushing idiom.**
   The existing tests use `await Future<void>.delayed(Duration.zero)` after pushing onto `f.channel.stateController` (broadcast stream delivery is microtask-scheduled). Use the exact same idiom in new tests — do **not** invent alternative wording like "await microtask".

8. **After `complete`, a follow-up `ready+breath` does NOT call `channel.start` again.**
   On the post-complete emission, `_previousStatus == complete` and the new emission's `status == breath`. None of the four lifecycle branches inside `_handleLifecycle` match (`wasPaused=false`, `wasActive=false`, status is not `complete`), so lifecycle does nothing — no spurious `start` call. Tests in this scenario (Phase 1 sub-test 6) must assert `f.channel.startCalls.length == 1` and must NOT tolerate a second start.

## Tasks

### Phase 1: Instruction dispatch

- [x] **Task 1: `BreathModuleStateChannel — instruction dispatch`**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`

  All multi-emission tests below must pre-prime `_previousPhase` / `_previousExerciseIndex` via an initial `ready+pause` emission (see Note 1 above), so that exactly **one** `sendSampleCalls` entry is expected per phase change unless otherwise noted.

  Test cases:
  - `should call instructionStream.sendSample with the moduleSessionId, phase name, and currentIntervalMs when phase changes while status=breath and a moduleSessionId is available`
    Setup: seed ModuleState with `moduleSessionId='sid'`; emit `ready+pause` with `phase=inhale, exerciseIndex=0` to prime previous fields; emit `ready+breath` with `phase=exhale, exerciseIndex=0, currentIntervalMs=5000`. Assert `sendSampleCalls` has exactly one entry: `('sid', 'exhale', 5000)`.
  - `should call instructionStream.sendSample when exerciseIndex changes while phase stays the same, status=breath, and a moduleSessionId is available`
    Setup: seed ModuleState; prime via `ready+pause` (`phase=inhale, exerciseIndex=0`); emit `ready+breath` (`phase=inhale, exerciseIndex=1, currentIntervalMs=5000`). Assert exactly one entry `('sid', 'inhale', 5000)`.
  - `should call instructionStream.sendSample exactly once when phase and exerciseIndex change simultaneously` (guards against `phaseChanged` ever being split into two separate conditions)
    Setup: seed ModuleState; prime via `ready+pause` (`phase=inhale, exerciseIndex=0`); emit `ready+breath` (`phase=exhale, exerciseIndex=1, currentIntervalMs=5000`). Assert `sendSampleCalls.length == 1`.
  - `should not call instructionStream.sendSample when a state emission keeps phase and exerciseIndex unchanged`
    Setup: seed ModuleState; emit `ready+breath` (`phase=inhale, exerciseIndex=0`) — this is the first emission and will dispatch; then emit another `ready+breath` with the same `phase` and `exerciseIndex` but a different `currentIntervalMs`. Assert `sendSampleCalls.length == 1` (no second call).
  - `should not call instructionStream.sendSample when a state emission has status=pause regardless of phase change` (covers the `!isActive` guard for `pause`)
    Setup: seed ModuleState; emit `ready+breath` (`phase=inhale, exerciseIndex=0`) → dispatches once; then emit `ready+pause` (`phase=exhale`). Assert `sendSampleCalls.length == 1`.
  - `should not call instructionStream.sendSample when a phase change occurs after the session has ended` (covers the `_ended` guard)
    Setup: seed ModuleState; emit `ready+breath` (`phase=inhale, exerciseIndex=0`) → 1st dispatch; assert `sendSampleCalls.length == 1` at this point; then drive lifecycle to `complete` (e.g. emit `ready+complete`) — lifecycle-only, no dispatch (`!isActive`); then emit a `ready+breath` state with a different phase (`phase=exhale`). Assert `sendSampleCalls.length` is **still** `1` after the post-complete emission. Also assert `f.channel.startCalls.length == 1` (see Note 8 — no spurious second `start`).
  - `should call instructionStream.sendSample when status=rest and phase changes while a moduleSessionId is available` (proves the active check covers both `breath` and `rest`)
    Setup: seed ModuleState; prime via `ready+pause` (`phase=inhale, exerciseIndex=0`); emit `ready+breath` (`phase=inhale, exerciseIndex=0`) to start the lifecycle (note: this `ready+breath` emission starts the lifecycle but does **not** dispatch, because `_previousPhase` was primed to `inhale` by the prior pause — `phaseChanged` evaluates to `false`); then emit `ready+rest` (`phase=exhale, currentIntervalMs=6000`). Assert `sendSampleCalls.length == 1` and `sendSampleCalls.last == ('sid', 'exhale', 6000)`.
  - `should pass currentIntervalMs through unchanged when it equals -1 (the real initial-state value)`
    Setup: seed ModuleState; prime via `ready+pause` (`phase=inhale, exerciseIndex=0`); emit `ready+breath` (`phase=exhale, exerciseIndex=0, currentIntervalMs=-1`). Assert the entry is `('sid', 'exhale', -1)` — confirms no defensive normalisation.

### Phase 2: Pending flush

- [x] **Task 2: `BreathModuleStateChannel — pending flush`**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  Test cases:
  - `should not call instructionStream.sendSample immediately when a phase change occurs while moduleSessionId is null`
    Setup: do **not** seed any ModuleState; prime via `ready+pause` (`phase=inhale`); emit `ready+breath` (`phase=exhale, currentIntervalMs=5000`). Assert `sendSampleCalls.isEmpty`. (Buffering is proved by the next test — this case only asserts no immediate dispatch.)
  - `should call instructionStream.sendSample exactly once with the buffered phase and currentIntervalMs when a ModuleState with a non-null moduleSessionId arrives after a buffered phase change` (combined buffer + flush proof)
    Setup: do **not** seed any ModuleState; prime via `ready+pause`; emit `ready+breath` (`phase=exhale, currentIntervalMs=5000`); then push `ModuleState(moduleSessionId: 'sid', status: active)` onto `f.channel.stateController` and `await Future<void>.delayed(Duration.zero)`. Assert `sendSampleCalls` has exactly one entry: `('sid', 'exhale', 5000)`.
  - `should not call instructionStream.sendSample again when a second ModuleState with the same moduleSessionId arrives after a buffered phase change has already been flushed (buffer is cleared)`
    Setup: same as above through the flush; then push a second `ModuleState(moduleSessionId: 'sid', status: active)` and `await Future<void>.delayed(Duration.zero)`. Assert `sendSampleCalls.length == 1`.
  - `should not call instructionStream.sendSample when a ModuleState with a non-null moduleSessionId arrives before any phase change has occurred`
    Setup: push `ModuleState(moduleSessionId: 'sid', status: active)` immediately after construction with no prior `BreathSessionState` emission; `await Future<void>.delayed(Duration.zero)`. Assert `sendSampleCalls.isEmpty`.
  - `should overwrite the pending instruction with the latest state when multiple phase changes occur before moduleSessionId becomes available, flushing only the most recent one`
    Setup: no seeded ModuleState; prime via `ready+pause`; emit `ready+breath` (`phase=exhale, currentIntervalMs=5000`); emit `ready+breath` (`phase=inhale, exerciseIndex=1, currentIntervalMs=6000`) — note: the second `ready+breath` short-circuits inside `_handleLifecycle` because `status == _previousStatus == breath`, but `_handleInstruction` is still called from `_onState` after lifecycle returns and overwrites `_pendingInstruction` (see Note 5); then push `ModuleState(moduleSessionId: 'sid')` and `await Future<void>.delayed(Duration.zero)`. Assert `sendSampleCalls == [('sid', 'inhale', 6000)]`.
  - `should call instructionStream.sendSample with the arguments derived from the buffered state, not from any non-ready state emitted between buffering and flush`
    Setup: no seeded ModuleState; prime via `ready+pause`; emit `ready+breath` (`phase=exhale, currentIntervalMs=5000`); emit a non-ready state (`loadState=loading`, any other fields); then push `ModuleState(moduleSessionId: 'sid')` and `await Future<void>.delayed(Duration.zero)`. Assert the single flushed entry is `('sid', 'exhale', 5000)` — the non-ready emission must not overwrite the pending state.

### Phase 3: Reset and dispose — instruction-state and subscription bookkeeping

- [x] **Task 3: `BreathModuleStateChannel — reset() clears instruction state`**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  Test cases:
  - `should clear moduleSessionId on reset, verified by emitting a phase change after reset and then pushing a new ModuleState — the new sessionId must appear in the dispatched instruction args`
    Setup: seed ModuleState `('sid-A', active)`; drive a phase change so an instruction with `'sid-A'` is dispatched; call `reset()`; emit a phase change (no new ModuleState yet) and assert no immediate dispatch (buffered); then push `ModuleState('sid-B', active)` and `await Future<void>.delayed(Duration.zero)`. Assert the flushed call uses `'sid-B'` (proving `_moduleSessionId` was cleared — otherwise the pre-reset `'sid-A'` would have caused immediate dispatch instead of buffering). Tolerate `f.channel.startCalls.length == 2`.
  - `should clear _pendingInstruction on reset, verified by buffering a phase change, calling reset, then pushing a ModuleState and observing no sendSample call`
    Setup: no seeded ModuleState; prime via `ready+pause`; emit `ready+breath` to buffer; call `reset()`; push `ModuleState('sid', active)` and `await Future<void>.delayed(Duration.zero)`. Assert `sendSampleCalls.isEmpty`.
  - `should clear _previousPhase on reset, verified by emitting the same phase before and after reset while moduleSessionId is available and observing a fresh sendSample call after reset`
    Setup: seed ModuleState `('sid', active)`; emit `ready+pause` (`phase=inhale`); emit `ready+breath` (`phase=exhale, currentIntervalMs=4000`) → 1st dispatch. Then call `reset()`. **Re-seed: push `ModuleState('sid', active)` onto `f.channel.stateController` and `await Future<void>.delayed(Duration.zero)`** (this restores `_moduleSessionId` because `reset()` cleared it; this test isolates the `_previousPhase`-cleared contract from the `_pendingInstruction` flow — see Note 4). Then emit `ready+pause` (`phase=inhale`); emit `ready+breath` (`phase=exhale, currentIntervalMs=5000`) → expected 2nd dispatch. Assert `sendSampleCalls.length == 2` and the second entry equals `('sid', 'exhale', 5000)`. Tolerate `f.channel.startCalls.length == 2`.
  - `should clear _previousExerciseIndex on reset, verified by emitting the same exerciseIndex pattern before and after reset and observing a fresh sendSample call after reset`
    Setup: analogous to the previous test but varying `exerciseIndex` instead of `phase`. Seed ModuleState `('sid', active)`; emit `ready+pause` (`phase=inhale, exerciseIndex=0`); emit `ready+breath` (`phase=inhale, exerciseIndex=1, currentIntervalMs=4000`) → 1st dispatch. Then call `reset()`. **Re-seed: push `ModuleState('sid', active)` and `await Future<void>.delayed(Duration.zero)`** (restores `_moduleSessionId`; isolates the `_previousExerciseIndex`-cleared contract). Then emit `ready+pause` (`phase=inhale, exerciseIndex=0`); emit `ready+breath` (`phase=inhale, exerciseIndex=1, currentIntervalMs=5000`) → expected 2nd dispatch. Assert `sendSampleCalls.length == 2` and the second entry equals `('sid', 'inhale', 5000)`. Tolerate `f.channel.startCalls.length == 2`.
  - `should keep the channel.state subscription alive across reset, verified by pushing a new ModuleState after reset and observing the updated moduleSessionId is used on the next phase-change instruction dispatch`
    Setup: construct fixture; call `reset()` immediately; push `ModuleState('sid-new', active)` and `await Future<void>.delayed(Duration.zero)`; prime via `ready+pause`; emit `ready+breath` (`phase=exhale, currentIntervalMs=5000`). Assert the dispatched entry uses `'sid-new'`. Tolerate `f.channel.startCalls.length == 1` (no pre-reset start).

- [x] **Task 4: `BreathModuleStateChannel — dispose() subscription bookkeeping`**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`

  Note: existing `Phase 7: dispose() / stop()` group already covers `channel.stop` behaviour and `_stateSub` cancellation (lines 571, 582, 597, 622, 636). Do **not** duplicate those cases here. This group adds only the channel-state-subscription cancel test that is new to this milestone.

  Test cases:
  - `should cancel the channel.state subscription on dispose, verified by reading the moduleSessionId getter after pushing a ModuleState post-dispose`
    Setup: construct fixture; call `target.dispose()`; push `ModuleState(moduleSessionId: 'sid-after-dispose', status: active)` onto `f.channel.stateController`; `await Future<void>.delayed(Duration.zero)`. Assert `target.moduleSessionId` is `null` (its initial value), proving `_channelSub.cancel()` was called and the listener no longer fires. Also assert `f.instructionStream.sendSampleCalls.isEmpty` (no spurious flush either).
