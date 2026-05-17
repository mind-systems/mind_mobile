# Test Plan: BreathModuleStateChannel — lifecycle transitions

## Context
`BreathModuleStateChannel` (`lib/BreathModule/Core/BreathModuleStateChannel.dart`) subscribes to a `BreathSessionState` stream and translates session-status transitions into gRPC activity commands on `ModuleStateChannel` (`start`, `unpause`, `pause`, `end`, `stop`). This plan covers the lifecycle-transition half of its behaviour: which command is dispatched for each status transition, the duplicate-emission (status-unchanged) short-circuit, the one-shot `_started` / `_ended` guards, the `wasActive` short-circuit on pause, the `loadState != ready` filter that drops emissions before any internal field is touched, plus the lifecycle behaviour of `dispose()` (`stop()`) and `reset()`.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`/usr/local/bin/flutter test test/BreathModule/breath_module_state_channel_test.dart`

## Target Spec File
`test/BreathModule/breath_module_state_channel_test.dart`

## Tasks

### Phase 1: Test scaffolding

- [x] **Task 1: Hand-rolled fakes and `_make()` factory**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  Notes:
  - The `_state` helper's `currentIntervalMs` default of `4000` and `remainingTicks` default of `0` are scoped to **lifecycle tests in this file**; neither field is read by `_handleLifecycle`. When instruction-stream tests are added in a follow-up plan, both defaults should be revisited — the real `BreathSessionState.initial()` uses `currentIntervalMs: -1`, and positive defaults may mask off-by-one or boundary bugs in the initial-frame and remaining-ticks paths.
  - `_FakeInstructionStream` should be declared as `class _FakeInstructionStream implements BreathModuleInstructionStream` and route everything except `sendSample` through `noSuchMethod`. Do **not** subclass `BreathModuleInstructionStream`: its constructor requires a non-optional `instructionStream: ModuleInstructionStream`, which would force a second nested fake. `implements` keeps the fake surface flat and mirrors the `_FakeChannel` approach.
  - `_FakeChannel.stateController` must be constructed as `StreamController<ModuleState>.broadcast()` and **must not seed any initial event**. The SUT does not assume an initial `moduleSessionId`, and seeding one would silently change the instruction-path tests in the follow-up plan. Pin this in a code comment next to the controller field.
  Test cases:
  - Define `_FakeChannel implements ModuleStateChannel` — records every call to `start({required ActivityType type, String? refId})`, `unpause()`, `pause()`, `end()`, `stop()` in typed lists (e.g. `startCalls` capturing a `(ActivityType, String?)` record; `pauseCount`, `unpauseCount`, `endCount`, `stopCount`); owns a `StreamController<ModuleState>.broadcast()` exposed as `stateController` (no seeded events); exposes `Stream<ModuleState> get state => stateController.stream`; routes anything else through `noSuchMethod` so the fake compiles without re-implementing the full `ModuleStateChannel` surface.
  - Define `_FakeInstructionStream implements BreathModuleInstructionStream` whose `sendSample(String sessionId, String phase, int durationMs)` only appends an `(sessionId, phase, durationMs)` record to a `sendSampleCalls` list (no real gRPC work); everything else routed through `noSuchMethod`.
  - Define a `_state({required BreathSessionStatus status, BreathPhase phase = BreathPhase.inhale, int exerciseIndex = 0, SessionLoadState loadState = SessionLoadState.ready, int currentIntervalMs = 4000})` helper that returns a `BreathSessionState` with sensible defaults for the remaining required fields (`remainingTicks: 0`).
  - Define `_make({String sessionId = 'sess-1'})` that wires a `StreamController<BreathSessionState>.broadcast()` for `stateStream`, a `_FakeChannel`, and a `_FakeInstructionStream`; constructs `BreathModuleStateChannel`; returns a record exposing every handle (`channel`, `instructionStream`, `stateCtrl`, `target`, `dispose` closure) so each test can drive the inputs and assert against the fakes.
  - Confirm setup compiles by writing one trivial sanity test (`should construct without throwing`).

### Phase 2: BreathModuleStateChannel — start transitions

- [x] **Task 2: First active transition calls `start()` exactly once**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  Test cases:
  - `should call channel.start with ActivityType.breath and the constructor sessionId when the first emitted state has status=breath`
  - `should call channel.start with ActivityType.breath and the constructor sessionId when transitioning from pause to breath for the first time`
  - `should not call unpause or pause when start is dispatched on the first active transition`
  - `should not re-invoke start when the same breath state is emitted twice in a row`

- [x] **Task 3: Subsequent active transitions call `unpause()`, and active→active emits nothing**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  Notes:
  - The bullet about first emission being `rest` covers the `_previousStatus == null` branch of `wasPaused`. Rationale (start, not unpause) is in this task description, not in the test name.
  Test cases:
  - `should call unpause exactly once when transitioning pause -> breath after start has already happened`
  - `should call unpause exactly once when transitioning pause -> rest after start has already happened`
  - `should not call start again on a pause -> breath transition once a session has already been started`
  - `should call start (not unpause) when the very first emission is status=rest with no prior emission`
  - `should not call start, unpause, or pause when transitioning breath -> rest while active`
  - `should not call start, unpause, or pause when transitioning rest -> breath while active`

### Phase 3: BreathModuleStateChannel — pause transitions

- [x] **Task 4: Active -> pause dispatches `pause()`**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  Notes:
  - The `wasActive` predicate is the real gate that suppresses `pause()` when no prior active state has been observed. The inner `_started && !_ended` check in the pause branch is unreachable for the "never started" case (because `_started` is toggled inside `_onState` on the same emission that flips `_previousStatus` into an active value), so the inner guard is defensive/dead code for this branch. Test names below attribute correctly to `wasActive` and `status == _previousStatus` rather than to the unreachable `_started` guard.
  - The non-ready loadState bullet is moved to Phase 5 (it belongs to the loadState-filter task and was double-listed here).
  Test cases:
  - `should call channel.pause exactly once when transitioning breath -> pause`
  - `should call channel.pause exactly once when transitioning rest -> pause`
  - `should not call pause when the very first emission is status=pause (wasActive=false short-circuits the pause branch)`
  - `should not call pause when transitioning pause -> pause (status-unchanged short-circuit at the top of _handleLifecycle)`

### Phase 4: BreathModuleStateChannel — end transitions

- [x] **Task 5: Any active status -> complete dispatches `end()` once**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  Notes:
  - The "second complete emission" case is short-circuited at the top of `_handleLifecycle` by `if (status == _previousStatus) return;`, **not** by the `_ended` flag — control never reaches the `_ended` check for back-to-back `complete` emissions. Test names below attribute the suppression to the status-unchanged short-circuit.
  - The actual `_ended` gate (preventing a second `end()` after `complete → pause → complete`) is exercised by the last bullet. Keep this case **unconditionally** — in this unit test the `stateStream` is a `StreamController` driven directly, so the test can emit any sequence regardless of whether the real state machine would produce it. The case exercises the only otherwise-untested branch of `_handleLifecycle`.
  - The "never started" case is correctly attributed to the `_started && !_ended` guard in the complete branch — that branch's inner guard *is* the actual gate, unlike the pause branch.
  Test cases:
  - `should call channel.end exactly once when transitioning breath -> complete`
  - `should call channel.end exactly once when transitioning rest -> complete`
  - `should call channel.end exactly once when transitioning pause -> complete after the session was started`
  - `should not call channel.end on a second complete emission (status-unchanged short-circuit)`
  - `should not call channel.end when complete is emitted before any start (the _started guard in the complete branch suppresses end)`
  - `should not call channel.end a second time when a complete -> pause -> complete sequence is emitted (the _ended guard prevents duplicate end)`

### Phase 5: BreathModuleStateChannel — loadState filter

- [x] **Task 6: Non-ready loadState emissions are fully ignored**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  Test cases:
  - `should not call start when a state with status=breath and loadState=loading is emitted`
  - `should not call pause when a state with status=pause and loadState=loading is emitted between two ready breath states`
  - `should not call end when a state with status=complete and loadState=error is emitted`
  - `should not update _previousStatus when a non-ready emission is filtered, verified by emitting ready breath -> non-ready pause -> ready breath and asserting no unpause call was dispatched between the two breath emissions`
  - `should resume dispatching lifecycle calls correctly once a ready emission follows a filtered one, verified by ready breath -> non-ready breath -> ready pause emitting exactly one pause`

### Phase 6: BreathModuleStateChannel — dispose() / stop()

- [x] **Task 7: `dispose()` dispatches `stop()` only while a started session is still in flight**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  Notes:
  - `dispose()` calls `_channel.stop()` iff `_started && !_ended`. Three observable branches: not started, started-and-active, started-and-ended.
  - The post-dispose-silence assertion is covered by a single dedicated test case (the final bullet below) rather than appended to each of the three branch cases. That test confirms `_stateSub.cancel()` runs unconditionally by emitting on `stateCtrl` after `dispose()` and asserting no further lifecycle calls; one case is sufficient because the cancel call is the same in all three branches.
  Test cases:
  - `should not call channel.stop when dispose is invoked before any state has been emitted`
  - `should not call channel.stop when dispose is invoked after only non-ready emissions have arrived`
  - `should call channel.stop exactly once when dispose is invoked while the session is started and not yet ended (breath -> dispose)`
  - `should call channel.stop exactly once when dispose is invoked while the session is paused after being started (breath -> pause -> dispose)`
  - `should not call channel.stop when dispose is invoked after the session has already completed (breath -> complete -> dispose)`
  - `should not dispatch any further lifecycle calls when state emissions arrive after dispose has run`

### Phase 7: BreathModuleStateChannel — reset()

- [x] **Task 8: `reset()` clears lifecycle bookkeeping so the next emission starts a fresh session**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  Notes:
  - `reset()` clears `_started`, `_ended`, `_previousStatus`, `_previousPhase`, `_previousExerciseIndex`, `_moduleSessionId`, `_pendingInstruction` while leaving subscriptions alive. Lifecycle-half tests focus on `_started`, `_ended`, and `_previousStatus`.
  - Cases below cover the three observable consequences: (a) next active emission goes through the `!_started` branch and dispatches `start()` again, not `unpause()`; (b) without a fresh `start`, `complete` cannot reach `end()`; (c) the surviving `stateStream` subscription continues to deliver events to `_onState` after reset.
  - The status-unchanged short-circuit reset (`_previousStatus = null`) is **not directly observable through fake call counts** on its own. The only status whose dispatch survives a freshly-reset `_previousStatus=null` is `breath`/`rest` (start branch); `pause` is gated by `wasActive` (which requires a prior active emission that `reset()` has wiped), and `complete` is gated by `_started` (also wiped). Trying to probe the short-circuit clear via a `pause` after reset would observe *no* dispatch (wasActive=false), which is indistinguishable from the no-reset case. So no dedicated test for the short-circuit clear in this phase — the start-after-reset cases (bullets 1 and 2) already exercise the path where `_previousStatus` must have been cleared (otherwise the second active-after-reset emission would short-circuit before reaching the start branch when the pre-reset status was also active).
  - Bullet 4 (subscription liveness) overlaps observably with bullet 1 (both emit `breath` after reset and assert `start`). To make the liveness aspect demonstrable, **re-use the same `stateCtrl` from the pre-reset phase** within a single test body (drive a breath emission, call `reset()`, drive another breath emission on the same controller, assert two `start` calls). The proof of liveness is that the second event reached `_onState` at all.
  Test cases:
  - `should call channel.start (not unpause) on the next breath emission after reset, even if the session had previously been started`
  - `should call channel.start (not unpause) on the next rest emission after reset, exercising the wasPaused=null branch`
  - `should not call channel.end when complete is emitted after reset with no fresh start in between`
  - `should keep the stateStream subscription alive across reset, verified by driving a ready breath on the same stateCtrl after reset and observing a second start call`
