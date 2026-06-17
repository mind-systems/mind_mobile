# MeditationModuleStateChannel — Test Plan

**Date:** 2026-06-17
**Source:** roadmap-test-coverage agent (updated)

## Source Overview

`MeditationModuleStateChannel` (`lib/MeditationModule/Core/MeditationModuleStateChannel.dart`) adapts a `Stream<MeditationSessionState>` into gRPC calls on `ModuleStateChannel`. It listens for status transitions (idle ↔ active) and dispatches lifecycle commands: `start()` on the first active emission, `end()` + re-arm (both `_started` and `_ended` reset to `false`) on transition to idle. It also subscribes to the channel's `state` stream to capture the server-assigned `moduleSessionId` for downstream use. Unlike `BreathModuleStateChannel`, it has no instruction stream or pending buffers.

**API change (Phase 33):** The constructor parameter was renamed from `poseId` to `refId`. The channel `state` subscription (`_channelSub`) was added alongside the existing `_stateSub`.

## Instantiation

### Constructor
```dart
MeditationModuleStateChannel({
  required ModuleStateChannel channel,
  required Stream<MeditationSessionState> stateStream,
  required String refId,
})
```

### What to Fake
- **`ModuleStateChannel`**: A mock capturing calls to `start()`, `end()`, `stop()`. Must also expose a `StreamController<ModuleState>` for its `state` property so tests can push `ModuleState(moduleSessionId: 'sid')` events.
  - Implement as a minimal class with:
    - `List<(ActivityType, String?)> startCalls = []`
    - `int endCount = 0, stopCount = 0`
    - `StreamController<ModuleState> stateController = StreamController<ModuleState>.broadcast()`
    - `Stream<ModuleState> get state => stateController.stream`
    - Methods that append to these lists
- **`stateStream`**: A `StreamController<MeditationSessionState>.broadcast()`.
  - Drive emissions via `stateCtrl.add(MeditationSessionState(...))`.

### Fixture Pattern
```dart
typedef _Fixture = ({
  _FakeChannel channel,
  StreamController<MeditationSessionState> stateCtrl,
  MeditationModuleStateChannel target,
});

_Fixture _make({String refId = 'pose-uuid-1'}) {
  final channel = _FakeChannel();
  final stateCtrl = StreamController<MeditationSessionState>.broadcast();
  final target = MeditationModuleStateChannel(
    channel: channel,
    stateStream: stateCtrl.stream,
    refId: refId,
  );
  return (channel: channel, stateCtrl: stateCtrl, target: target);
}
```

## Existing Coverage

None. Reference `test/BreathModule/breath_module_state_channel_test.dart` as the scaffolding model; adapt the fake channel, fixture pattern, and test grouping to meditation's simpler contract.

## Test Cases

### Scaffolding (Phase 1)

- **should construct without throwing** when all required parameters are provided
  - Exercise: instantiation only
  - Setup: call `_make()`, dispose

### Start Transitions (Phase 2)

- **should call channel.start with ActivityType.meditation and the constructor refId when the first emitted state has status=active**
  - Exercise: `_onState()` → first status check → start branch
  - Setup: emit `active`, await pump, assert `startCalls.length == 1` and `startCalls.first == (ActivityType.meditation, 'pose-uuid-1')`
  - Verify: `_started` flag is set

- **should call channel.start with ActivityType.meditation and the constructor refId when transitioning from idle to active for the first time**
  - Exercise: idle → active (explicit transition)
  - Setup: emit `idle`, pump, emit `active`, pump, assert single start call
  - Verify: `_started` flag is set; `_previousStatus` updated to active

- **should not re-invoke start when the same active state is emitted twice in a row**
  - Exercise: status-unchanged short-circuit: `if (status == _previousStatus) return`
  - Setup: emit `active`, pump, emit `active` again, pump, assert `startCalls.length == 1`
  - Verify: `_previousStatus` prevents duplicate dispatch

### Re-arm Transitions (Phase 3)

- **should call channel.end exactly once when transitioning from active to idle**
  - Exercise: `_onState()` → idle branch
  - Setup: emit `active`, pump, emit `idle`, pump, assert `endCount == 1`
  - Verify: `_started = false` and `_ended = false` are reset (re-arm for next cycle)

- **should not call channel.end when idle is emitted before any active (the _started guard suppresses end)**
  - Exercise: guard `if (status == MeditationSessionStatus.idle && _started && !_ended)` — `_started` is false
  - Setup: emit `idle` without prior `active`, pump, assert `endCount == 0`
  - Verify: early return prevents spurious end call

- **should not call channel.end a second time on a second idle emission**
  - Exercise: redundant idle detection
  - Setup: emit `active`, pump, emit `idle`, pump, emit `idle`, pump, assert `endCount == 1`
  - Verify: both `_previousStatus == idle` short-circuit (first repetition) and `_started = false` (already re-armed) prevent duplication

- **should allow a fresh start → end cycle after the first cycle completes (re-arm re-enables the next start)**
  - Exercise: verify `_started` and `_ended` flags are both reset to false in the idle branch
  - Setup: emit `active`, pump, emit `idle`, pump, assert `startCalls.length == 1`, then emit `active`, pump, assert `startCalls.length == 2`
  - Verify: second `start()` call proves re-arm worked; both cycles are independent

### Status Unchanged / Idempotence (Phase 4)

- **should not call start or end when the same idle state is emitted twice in a row**
  - Exercise: status-unchanged short-circuit
  - Setup: emit `idle`, pump, emit `idle`, pump, assert `startCalls.length == 0` and `endCount == 0`

- **should emit only one end on an active → idle → idle sequence**
  - Exercise: re-arm and status-unchanged combination
  - Setup: emit `active`, `idle`, `idle`, pump each, assert `endCount == 1`
  - Verify: second `idle` caught by short-circuit at `_previousStatus` check

### moduleSessionId Capture (Phase 5)

- **should capture moduleSessionId when channel.state emits a ModuleState with a non-null id**
  - Exercise: `_channelSub` listener
  - Setup: push `ModuleState(moduleSessionId: 'sid')` on `channel.stateController`, pump, assert `target.moduleSessionId == 'sid'`

- **should not update moduleSessionId when channel.state emits a ModuleState with a null id**
  - Exercise: `if (moduleState.moduleSessionId != null)` guard
  - Setup: push `ModuleState(moduleSessionId: 'sid')`, pump, then push `ModuleState(moduleSessionId: null)`, pump, assert `target.moduleSessionId == 'sid'`

- **should return null for moduleSessionId before any ModuleState arrives**
  - Exercise: getter initial value
  - Setup: call `_make()`, assert `target.moduleSessionId == null`

### Dispose (Phase 6)

- **should not call channel.stop when dispose is invoked before any state has been emitted**
  - Exercise: `dispose()` → guard `if (_started && !_ended)` — `_started` is false
  - Setup: call `_make()`, dispose immediately, assert `stopCount == 0`

- **should call channel.stop exactly once when dispose is invoked while the session is active**
  - Exercise: `dispose()` → stop branch
  - Setup: emit `active`, pump, dispose, assert `stopCount == 1`
  - Verify: `_stateSub.cancel()` and `_channelSub.cancel()` both called

- **should not call channel.stop when dispose is invoked after an active → idle cycle**
  - Exercise: after idle, `_started = false` prevents stop
  - Setup: emit `active`, pump, emit `idle`, pump, dispose, assert `stopCount == 0`
  - Verify: stop is prevented because `_started = false` (not because `_ended = true` — the re-arm sets `_ended = false` too)

- **should cancel _channelSub on dispose — pushing a ModuleState after dispose does not update moduleSessionId**
  - Exercise: `_channelSub.cancel()` in dispose
  - Setup: emit `active`, pump, dispose, push `ModuleState(moduleSessionId: 'late')` on stateController, pump, assert `target.moduleSessionId == null`

- **should not dispatch any further lifecycle calls when state emissions arrive after dispose**
  - Exercise: `_stateSub.cancel()` in dispose
  - Setup: emit `active`, pump, dispose, emit `idle`, pump, assert only one start call and zero end calls

### Stress Tests (Phase 7)

- **should handle rapid active → idle → active cycles without missing calls**
  - Exercise: stress test re-arm logic
  - Setup: emit `active`, `idle`, `active`, `idle`, `active` in quick succession, await pumps between each, assert `startCalls.length == 3` and `endCount == 2`

- **should handle refId being empty or special characters**
  - Exercise: refId parameterization
  - Setup: construct with `refId = ''`, emit `active`, pump, assert `startCalls.first.$2 == ''`

## Gotchas

### One-shot Flags and Re-arm Behavior
- `_started` and `_ended` are **both reset to `false`** on the idle→active→idle cycle (not `_ended = true`). After `idle`, the dispose guard `if (_started && !_ended)` fires as `if (false && ...)` = false — stop is blocked because `_started = false`.
- The re-arm enables a second start → end cycle. Tests must verify the second `active` call re-invokes `start()`.

### Dispose During Active Session
- `dispose()` calls `stop()` only when `_started == true && _ended == false` — i.e., mid-session.
- `end()` is user-initiated; `stop()` is emergency cleanup. Tests must verify the correct path.

### Two Subscriptions
- The constructor creates two subscriptions: `_stateSub` (from stateStream) and `_channelSub` (from `channel.state`).
- Both must be cancelled in `dispose()`. Test by asserting no updates arrive after dispose on either pathway.

### PoseId → RefId Rename
- The constructor parameter is now `refId` (was `poseId` in Phase 28). The fake fixture must use `refId:`.
- The test plan for `startCalls` must assert `startCalls.first.$2 == refId` (passed as-is).
