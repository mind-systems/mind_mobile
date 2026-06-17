# Test Plan: MeditationModuleStateChannel lifecycle and re-arm tests

## Context
`MeditationModuleStateChannel` (`lib/MeditationModule/Core/MeditationModuleStateChannel.dart`) adapts a `Stream<MeditationSessionState>` into gRPC lifecycle calls on `ModuleStateChannel`: `start()` on the first `active` emission, `end()` + re-arm on the transition back to `idle`, and `stop()` on `dispose()` if a session is still in flight. It also captures the server-assigned `moduleSessionId` from `channel.state`. No tests currently exist for this class.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`/usr/local/bin/flutter test test/MeditationModule/meditation_module_state_channel_test.dart`

## Target Spec File
`test/MeditationModule/meditation_module_state_channel_test.dart`

## Source Notes (ground each test in these code paths)

`_onState` (lib/MeditationModule/Core/MeditationModuleStateChannel.dart:34-49):
- Top guard `if (status == _previousStatus) return;` — suppresses any duplicate consecutive status.
- `active && !_started` → `_channel.start(type: ActivityType.meditation, refId: _refId)`, then `_started = true`.
- `idle && _started && !_ended` → `_channel.end()`, then re-arm: `_started = false` **and** `_ended = false`.
- `_previousStatus = status` updated on every non-short-circuited emission.

`_channelSub` (constructor, lines 25-29): listens to `channel.state`; stores `moduleState.moduleSessionId` only when non-null. Exposed via `moduleSessionId` getter (initial value `null`).

`dispose` (lines 51-55): `if (_started && !_ended) _channel.stop();` then cancels both `_stateSub` and `_channelSub`.

## Fakes & Fixture (implementer setup — not a task)

- `_FakeChannel implements ModuleStateChannel` (mirror `test/BreathModule/breath_module_state_channel_test.dart`):
  - `List<(ActivityType, String?)> startCalls = []`
  - `int endCount = 0; int stopCount = 0;`
  - `final stateController = StreamController<ModuleState>.broadcast();`
  - `Stream<ModuleState> get state => stateController.stream;`
  - `start({required type, refId})` appends to `startCalls`; `end()`/`stop()` increment counters.
  - `dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);` for unused members.
- `stateStream`: `StreamController<MeditationSessionState>.broadcast()`.
- State helper: `MeditationSessionState` requires **both** `status` and `poseId` — build via `MeditationSessionState(status: ..., poseId: 'p')` (the channel only reads `status`; `poseId` is a required dummy).
- `_make({String refId = 'pose-uuid-1'})` returns `(channel, stateCtrl, target)` and constructs the channel with `refId:`.
- Pump after every emission with `await Future<void>.delayed(Duration.zero)` so the broadcast listener runs before assertions.
- Always `f.target.dispose()` at the end of each test.

## Tasks

### Phase 1: Scaffolding

- [x] **Task 1: `MeditationModuleStateChannel — scaffolding`**
  Files: `test/MeditationModule/meditation_module_state_channel_test.dart`
  Test cases:
  - `should construct without throwing when all required parameters are provided`
  - `should return null for moduleSessionId before any ModuleState arrives`

### Phase 2: Start transitions

- [x] **Task 2: `MeditationModuleStateChannel — start transitions`**
  Files: `test/MeditationModule/meditation_module_state_channel_test.dart`
  Test cases:
  - `should call channel.start with ActivityType.meditation and the constructor refId when the first emitted state has status=active`
  - `should call channel.start with ActivityType.meditation and the constructor refId when transitioning from idle to active for the first time`
  - `should not re-invoke start when the same active state is emitted twice in a row`
  - `should pass refId through unchanged when refId is an empty string`

### Phase 3: Re-arm transitions

- [x] **Task 3: `MeditationModuleStateChannel — re-arm transitions`**
  Files: `test/MeditationModule/meditation_module_state_channel_test.dart`
  Test cases:
  - `should call channel.end exactly once when transitioning from active to idle`
  - `should not call channel.end when idle is emitted before any active`
  - `should allow a fresh start when active is emitted again after an active to idle cycle`
  - `should call start twice and end twice across two full active to idle cycles`

### Phase 4: Status-unchanged idempotence

- [x] **Task 4: `MeditationModuleStateChannel — status-unchanged idempotence`**
  Files: `test/MeditationModule/meditation_module_state_channel_test.dart`
  Test cases:
  - `should not call start or end when the same idle state is emitted twice in a row`
  - `should call end only once when an active to idle to idle sequence is emitted`
  - `should handle rapid active to idle to active to idle to active cycles with three start calls and two end calls`

### Phase 5: moduleSessionId capture

- [x] **Task 5: `MeditationModuleStateChannel — moduleSessionId capture`**
  Files: `test/MeditationModule/meditation_module_state_channel_test.dart`
  Test cases:
  - `should capture moduleSessionId when channel.state emits a ModuleState with a non-null id`
  - `should not update moduleSessionId when channel.state emits a ModuleState with a null id after a non-null id`

### Phase 6: dispose

- [x] **Task 6: `MeditationModuleStateChannel — dispose`**
  Files: `test/MeditationModule/meditation_module_state_channel_test.dart`
  Test cases:
  - `should not call channel.stop when dispose is invoked before any state has been emitted`
  - `should call channel.stop exactly once when dispose is invoked while the session is active`
  - `should not call channel.stop when dispose is invoked after an active to idle cycle`
  - `should not dispatch any further lifecycle calls when state emissions arrive after dispose`
  - `should not update moduleSessionId when a ModuleState is pushed after dispose`
