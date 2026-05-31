# Plan: Implement `MeditationModuleStateChannel` adapter

## Context
Add a lifecycle-only adapter that bridges the meditation session's state stream to the gRPC `ModuleStateChannel`, opening/closing a server-side meditation activity as the session goes active and idle.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Prerequisites (verified)
- `ActivityType.meditation` exists in `lib/Core/Grpc/ActivityType.dart` ✓
- `ModuleStateChannel` exposes `start({required ActivityType type, String? refId})`, `end()`, `stop()` in `lib/Core/Grpc/ModuleStateChannel.dart` ✓
- **Depends on the `meditation_module` package** providing `MeditationSessionState` / `MeditationSessionStatus` (spec §B, Task 4). The adapter imports these from `package:meditation_module/meditation_module.dart`. This task assumes that package and its session state type already exist.

## Tasks

### Phase 1: Adapter

- [x] **Task 1: Create `MeditationModuleStateChannel` adapter**
  Files: `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`
  Create the new file by stripping `lib/BreathModule/Core/BreathModuleStateChannel.dart` down to lifecycle-only. Implement exactly the shape in `.ai-factory/notes/34-meditation-module-impl-specs.md` §C:
  - Fields: `final ModuleStateChannel _channel;`, `final String _poseId;`, `bool _started = false;`, `bool _ended = false;`, `MeditationSessionStatus? _previousStatus;`, `late final StreamSubscription<MeditationSessionState> _stateSub;`
  - Constructor `MeditationModuleStateChannel({required ModuleStateChannel channel, required Stream<MeditationSessionState> stateStream, required String poseId})` — assigns `_channel`/`_poseId`, then `_stateSub = stateStream.listen(_onState);`
  - `_onState(MeditationSessionState state)`: read `state.status`; return early if `status == _previousStatus`. On `idle → active` (`status == active && !_started`) call `_channel.start(type: ActivityType.meditation, refId: _poseId)` and set `_started = true`. On `active → idle` (`status == idle && _started && !_ended`) call `_channel.end()` and set `_ended = true`. Update `_previousStatus = status` at the end.
  - `dispose()`: if `_started && !_ended` call `_channel.stop()`; then `_stateSub.cancel()`.
  - Imports: `dart:async`, `package:mind/Core/Grpc/ActivityType.dart`, `package:mind/Core/Grpc/ModuleStateChannel.dart`, and `MeditationSessionState`/`MeditationSessionStatus` from `package:meditation_module/meditation_module.dart`.
  - **Deliberately absent** (do NOT port from breath): no `BreathModuleInstructionStream`, no `_channelSub` / `moduleSessionId` / `_pendingInstruction` / `_flushPending`, no `_handleInstruction`, no pause/resume branch, no phase / exercise-index tracking, no `reset()`, no `ModuleState` import. Logging is optional/minimal (breath's `dev.log` calls may be omitted).
