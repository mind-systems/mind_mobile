# Plan: Create BreathModuleStateChannel in lib/BreathModule/Core/

## Context

Bridge the BreathModule presentation state (`BreathSessionState` stream from `BreathViewModel`) to the infrastructure layer (`ModuleStateChannel`) by creating a single domain-layer class that detects session lifecycle transitions (start / pause / resume / end), forwards them as typed channel commands, tracks the server-assigned `liveSessionId`, and dispatches telemetry samples on phase changes. This absorbs both `LiveBreathSessionService` and `LiveBreathSessionCoordinator` into one class, eliminating the round-trip through the `ILiveBreathSessionService` interface.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Create BreathModuleStateChannel

- [x] **Task 1: Create `BreathModuleStateChannel.dart`**
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`

  Create a new class in the domain layer that absorbs the lifecycle logic from `LiveBreathSessionCoordinator` (in `packages/breath_module`) and the channel-command forwarding from `LiveBreathSessionService`.

  **Constructor parameters** (all injected, per RULES):
  - `ModuleStateChannel channel` — the infrastructure bidirectional gRPC channel
  - `Stream<BreathSessionState> stateStream` — the `BreathViewModel.stream` broadcast stream
  - `BreathTelemetryService telemetryService` — concrete type from `lib/BreathModule/Core/BreathTelemetryService.dart`; only calls `sendSample(liveSessionId, phase, durationMs)`
  - `String sessionId` — the breath session template ID, passed as `refId` to `channel.start()`

  **Constructor body** — subscribe to both streams:
  1. `stateStream.listen(_onState)` — detects lifecycle transitions and phase changes (mirrors `LiveBreathSessionCoordinator._onState`)
  2. `channel.state.listen(...)` — tracks `liveSessionId` from `ModuleState.liveSessionId`; when a non-null `liveSessionId` arrives, flush any pending telemetry sample (mirrors the `_liveSessionSub` + `_flushPending` logic in `LiveBreathSessionCoordinator`)

  **Private state** (mirrors `LiveBreathSessionCoordinator`):
  - `bool _started`, `bool _ended` — guards against duplicate start/end
  - `BreathSessionStatus? _previousStatus` — for diffing lifecycle transitions
  - `BreathPhase? _previousPhase`, `int? _previousExerciseIndex` — for detecting phase changes (telemetry)
  - `String? _liveSessionId` — server-assigned live session ID
  - `BreathSessionState? _pendingTelemetry` — buffered sample when `_liveSessionId` is still null

  **`_onState(BreathSessionState)`** — skip if `loadState != SessionLoadState.ready`, then call `_handleLifecycle` and `_handleTelemetry`, then update `_previousStatus`, `_previousPhase`, `_previousExerciseIndex`. Identical flow to `LiveBreathSessionCoordinator._onState`.

  **`_handleLifecycle(BreathSessionStatus)`** — translate status diffs into channel commands. Copy the transition logic from `LiveBreathSessionCoordinator._handleLifecycle`, replacing service calls with direct channel calls:
  - First active transition (`wasPaused && isActive && !_started`) → `_channel.start(type: ActivityType.breath, refId: _sessionId)`, set `_started = true`
  - Subsequent resume (`wasPaused && isActive && _started`) → `_channel.unpause()`
  - Active → pause (`wasActive && status == pause`) → `_channel.pause()`
  - Complete → `_channel.end()`, set `_ended = true`

  **`_handleTelemetry(BreathSessionState)`** — copy from `LiveBreathSessionCoordinator._handleTelemetry`. When phase or exerciseIndex changes while session is active, call `_telemetryService.sendSample(_liveSessionId, phase.name, currentIntervalMs)`. If `_liveSessionId` is null, store state in `_pendingTelemetry`.

  **`_flushPending(String liveId)`** — send the buffered sample and clear `_pendingTelemetry`. Identical to `LiveBreathSessionCoordinator._flushPending`.

  **Public API**:
  - `String? get liveSessionId` — exposes the current `_liveSessionId` for future consumption by `BreathModuleInstructionStream` (milestone 7.6)
  - `void reset()` — reset all tracking state for session restart (`_liveSessionId = null`, `_started = false`, `_ended = false`, clear previous status/phase/exerciseIndex, clear pending telemetry). Subscriptions stay alive — the stream is reused across restarts. Identical to `LiveBreathSessionCoordinator.reset()`.
  - `void dispose()` — if `_started && !_ended`, call `_channel.stop()` to notify the server of an abandoned session; cancel both stream subscriptions. Mirrors `LiveBreathSessionCoordinator.dispose()`.

  **Imports**: `dart:async`, `dart:developer`, `ModuleStateChannel`, `ModuleState`, `ActivityType` from `lib/Core/Grpc/`, `BreathTelemetryService` from `lib/BreathModule/Core/`, `BreathSessionState`/`BreathSessionStatus`/`BreathPhase`/`SessionLoadState` from `package:breath_module/breath_module.dart`.

### Phase 2: Rewire and clean up

- [x] **Task 2: Rewire `BreathModule.buildSession()` to use `BreathModuleStateChannel`** (depends on Task 1)
  Files: `lib/BreathModule/BreathModule.dart`

  Replace `LiveBreathSessionCoordinator` with `BreathModuleStateChannel` in the `buildSession` factory method:

  1. Remove the `LiveBreathSessionCoordinator` creation line.
  2. Declare `late final BreathModuleStateChannel stateChannel;` before the `ProviderScope`.
  3. Inside `breathViewModelProvider.overrideWith(() { ... })`, after creating `vm`, create the state channel:
     ```dart
     stateChannel = BreathModuleStateChannel(
       channel: App.shared.moduleStateChannel,
       stateStream: vm.stream,
       telemetryService: App.shared.telemetryService,
       sessionId: sessionId,
     );
     ```
  4. Update `BreathSessionScreen` callbacks to use **closure wrappers** (not method tear-offs): `onRestart: () => stateChannel.reset()` and `onDispose: () => stateChannel.dispose()`. Tear-offs like `stateChannel.reset` eagerly evaluate `stateChannel` at widget construction time, but the `late final` variable is only assigned inside the `overrideWith` factory which runs lazily when the provider is first read — this would cause a `LateInitializationError`. Closures capture `stateChannel` by name and defer evaluation until invocation (user tap / widget dispose), when the variable is guaranteed to be assigned.
  5. Remove the `import` of `LiveBreathSessionCoordinator` from `package:breath_module/breath_module.dart`. Add import for `BreathModuleStateChannel`.
  6. The `App.shared.liveSessionService` reference is no longer needed — remove it.

- [x] **Task 3: Remove `LiveBreathSessionService` from `App.dart`** (depends on Task 2)
  Files: `lib/Core/App.dart`

  1. Remove the `liveSessionService` field declaration (`final LiveBreathSessionService liveSessionService;`).
  2. Remove the corresponding `required this.liveSessionService` from the `App._()` constructor.
  3. Remove the initialization line: `final liveSessionService = LiveBreathSessionService(channel: moduleStateChannel);`.
  4. Remove `liveSessionService: liveSessionService` from the `App._()` call inside `initialize()`.
  5. Remove the `import` of `LiveBreathSessionService.dart`.

- [x] **Task 4: Delete absorbed files and clean up barrel exports** (depends on Tasks 2, 3)
  Files: `lib/BreathModule/Core/LiveBreathSessionService.dart`, `packages/breath_module/lib/src/BreathSession/LiveBreathSessionCoordinator.dart`, `packages/breath_module/lib/src/BreathSession/ILiveBreathSessionService.dart`, `packages/breath_module/lib/breath_module.dart`

  1. Delete `lib/BreathModule/Core/LiveBreathSessionService.dart`.
  2. Delete `packages/breath_module/lib/src/BreathSession/LiveBreathSessionCoordinator.dart`.
  3. Delete `packages/breath_module/lib/src/BreathSession/ILiveBreathSessionService.dart` (contains both `ILiveBreathSessionService` and `LiveBreathSessionDto` — neither is used after this milestone).
  4. In `packages/breath_module/lib/breath_module.dart`, remove these three export lines:
     - `export 'src/BreathSession/ILiveBreathSessionService.dart';`
     - `export 'src/BreathSession/LiveBreathSessionCoordinator.dart';`
  5. Verify no remaining imports reference the deleted files (`LiveBreathSessionService`, `ILiveBreathSessionService`, `LiveBreathSessionDto`, `LiveBreathSessionCoordinator`) in either `lib/` or `packages/`.
