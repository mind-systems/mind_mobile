# MeditationModuleStateChannel — Test Plan

**Date:** 2026-06-03
**Source:** roadmap-test-coverage agent

## Source Overview

`MeditationModuleStateChannel` (45 lines, `/lib/MeditationModule/Core/MeditationModuleStateChannel.dart`) adapts a `Stream<MeditationSessionState>` into gRPC calls on `ModuleStateChannel`. It listens for status transitions (idle ↔ active) and dispatches lifecycle commands: `start()` on the first active emission, `end()` + re-arm (flags cleared) on transition to idle. Unlike `BreathModuleStateChannel`, it has no instruction stream or pending buffers; the interface and state machine are much simpler.

## Instantiation

### Constructor
```dart
MeditationModuleStateChannel({
  required ModuleStateChannel channel,
  required Stream<MeditationSessionState> stateStream,
  required String poseId,
})
```

### What to Fake
- **`ModuleStateChannel`**: A mock capturing calls to `start()`, `end()`, `stop()`.
  - Implement as a minimal class with:
    - `List<(ActivityType, String?)> startCalls = []`
    - `int endCount = 0, stopCount = 0`
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

_Fixture _make({String poseId = 'pose-1'}) {
  final channel = _FakeChannel();
  final stateCtrl = StreamController<MeditationSessionState>.broadcast();
  final target = MeditationModuleStateChannel(
    channel: channel,
    stateStream: stateCtrl.stream,
    poseId: poseId,
  );
  return (channel: channel, stateCtrl: stateCtrl, target: target);
}
```

## Existing Coverage

None. Reference `test/BreathModule/breath_module_state_channel_test.dart` (lines 1–1235) as the scaffolding model; adapt the fake channel, fixture pattern, and test grouping to meditation's simpler contract.

## Test Cases

### Scaffolding (Phase 1)

- **should construct without throwing** when all required parameters are provided
  - Exercise: instantiation only
  - Setup: call `_make()`, dispose

### Start Transitions (Phase 2)

- **should call channel.start with ActivityType.meditation and the constructor poseId when the first emitted state has status=active**
  - Exercise: `_onState()` → first status check → start branch
  - Setup: emit `active`, await pump, assert `startCalls.length == 1` and `startCalls.first == (ActivityType.meditation, 'pose-1')`
  - Verify: `_started` flag is set

- **should call channel.start with ActivityType.meditation and the constructor poseId when transitioning from idle to active for the first time**
  - Exercise: idle → active (explicit transition)
  - Setup: emit `idle`, pump, emit `active`, pump, assert single start call
  - Verify: `_started` flag is set; `_previousStatus` updated to active

- **should not re-invoke start when the same active state is emitted twice in a row**
  - Exercise: status-unchanged short-circuit at line 26: `if (status == _previousStatus) return`
  - Setup: emit `active`, pump, emit `active` again, pump, assert `startCalls.length == 1`
  - Verify: `_previousStatus` prevents duplicate dispatch

### Re-arm Transitions (Phase 3)

- **should call channel.end exactly once when transitioning from active to idle**
  - Exercise: `_onState()` → idle branch (lines 31–37)
  - Setup: emit `active`, pump, emit `idle`, pump, assert `endCount == 1`
  - Verify: `_started = false` and `_ended = false` are reset (re-arm)

- **should not call channel.end when idle is emitted before any active (the _started guard suppresses end)**
  - Exercise: guard `if (status == MeditationSessionStatus.idle && _started && !_ended)` — _started is false
  - Setup: emit `idle` without prior `active`, pump, assert `endCount == 0`
  - Verify: early return prevents spurious end call

- **should not call channel.end a second time on a second idle emission (the _previousStatus short-circuit and _ended guard combine)**
  - Exercise: redundant idle detection
  - Setup: emit `active`, pump, emit `idle`, pump, emit `idle`, pump, assert `endCount == 1`
  - Verify: both `_previousStatus == idle` short-circuit and `_ended = true` guard prevent duplication

- **should allow a fresh start → end cycle after the first cycle completes (re-arm re-enables the next start)**
  - Exercise: verify `_started` and `_ended` flags are both cleared in the idle branch
  - Setup: emit `active`, pump, emit `idle`, pump, assert `startCalls.length == 1`, then emit `active`, pump, assert `startCalls.length == 2`
  - Verify: second `start()` call proves re-arm worked; both cycles are independent

### Status Unchanged / Idempotence (Phase 4)

- **should not call start or end when the same idle state is emitted twice in a row (status-unchanged short-circuit)**
  - Exercise: line 26 short-circuit
  - Setup: emit `idle`, pump, emit `idle`, pump, assert `startCalls.length == 0` and `endCount == 0`
  - Verify: `_previousStatus` short-circuits before any branch

- **should not call end on an idle → active → idle → idle sequence (double idle emits only one end)**
  - Exercise: re-arm and status-unchanged combination
  - Setup: emit `active`, `idle`, `idle`, pump each, assert `endCount == 1`
  - Verify: second `idle` is caught by short-circuit at line 26

### Dispose (Phase 5)

- **should not call channel.stop when dispose is invoked before any state has been emitted**
  - Exercise: `dispose()` → guard `if (_started && !_ended)` — _started is false
  - Setup: call `_make()`, dispose immediately, assert `stopCount == 0`
  - Verify: subscription is cancelled cleanly

- **should call channel.stop exactly once when dispose is invoked while the session is active and not yet ended (active → dispose)**
  - Exercise: `dispose()` → stop branch (line 42)
  - Setup: emit `active`, pump, dispose, assert `stopCount == 1`
  - Verify: `_stateSub.cancel()` is called

- **should call channel.stop exactly once when dispose is invoked while the session is active but has emitted idle (active → idle → active → dispose)**
  - Exercise: confirm lifecycle: after idle emission, both `_started` and `_ended` are reset; next active re-arms; dispose should fire stop if still active
  - Setup: emit `active`, idle, `active`, pump, dispose, assert `stopCount == 1`
  - Verify: second active re-set the flags; dispose sees `_started=true, _ended=false`

- **should not call channel.stop when dispose is invoked after the session has already completed (active → idle → dispose)**
  - Exercise: guards in line 42: both `_started` and `_ended` must be true
  - Setup: emit `active`, pump, emit `idle`, pump, dispose, assert `stopCount == 0`
  - Verify: `_ended = true` from idle branch prevents stop

- **should not dispatch any further lifecycle calls when state emissions arrive after dispose has run**
  - Exercise: subscription cancelled at line 43
  - Setup: emit `active`, pump, dispose, emit `idle`, pump, assert only one start call and zero end calls
  - Verify: `_stateSub.cancel()` prevents listener from firing

### Stress Tests (Phase 6)

- **should handle rapid active → idle → active cycles without missing calls**
  - Exercise: stress test re-arm logic
  - Setup: emit `active`, `idle`, `active`, `idle`, `active` in quick succession, await pumps between each, assert `startCalls.length == 3` and `endCount == 2`
  - Verify: each cycle is independent

- **should handle poseId being empty or special characters**
  - Exercise: poseId parameterization
  - Setup: construct with `poseId = ''`, emit `active`, pump, assert `startCalls.first.$2 == ''`
  - Verify: no validation; poseId is passed through as-is

- **should handle multiple rapid idle emissions between active states**
  - Exercise: confirm short-circuit under spam
  - Setup: emit `active`, `idle`, `idle`, `idle`, pump after each, assert `endCount == 1` and `startCalls.length == 1`
  - Verify: short-circuit blocks all but the first idle

## Gotchas

### One-shot Flags and Re-arm Behavior
- `_started` and `_ended` are reset to `false` on line 35–36, *only* when transitioning to idle, not on every state change. This enables a second start → end cycle. Tests must verify that:
  - After the first `idle`, a second `active` emission re-invokes `start()` (not just `unpause()` or a silent no-op).
  - The flags are independent: `_ended = false` does not depend on `_started = false`; both must be reset together.
  - If dispose fires during the active state, `stop()` is called (not `end()`), and `_started` or `_ended` state is irrelevant.

### Dispose During Active Session
- `dispose()` at line 42 checks `if (_started && !_ended) _channel.stop()`. This is **not** the same as `end()`:
  - `end()` is a user-initiated "I'm done with this session" command dispatched during the idle transition.
  - `stop()` is an emergency halt called by the client during cleanup (e.g., app backgrounding, widget destruction).
  - Tests must distinguish these two paths: emit `active` → dispose (expect `stop()`, not `end()`).

### Stream Subscription Timing
- The subscription is created in the constructor at line 21 and is **never re-created**. Re-arm does not involve re-subscribing.
- Emitting after dispose has run should produce no listener callback. If a test emits post-dispose and expects no call, the pump is critical for proving the subscription is dead.
- The `StreamController` is owned by the caller; this class cancels its subscription but does not close the controller. Tests must clean up the controller manually if needed.

### Status Comparison
- Line 26 uses `==` on `MeditationSessionStatus?`. `_previousStatus` is nullable (initialized to `null`). The first emission always passes the status-unchanged check unless the first status is literally `null` (impossible in well-formed tests).
- Ensure test emissions never skip the status change (e.g., active → active yields a no-op, as expected).

### PoseId Storage
- `_poseId` is captured in the constructor and never mutated. It is used in every `start()` call. Tests parameterizing `poseId` must verify it propagates to the call args.

### Integration with ModuleStateChannel
- `ModuleStateChannel.start()` accepts `ActivityType` and `refId: String?`. This class always passes `ActivityType.meditation` and `poseId` (never `null` or empty unless constructed that way).
- The fake must not validate these; it just records them for assertion.
