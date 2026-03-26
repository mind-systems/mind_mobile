# Plan: Replace SocketConnectionCoordinator.dart

## Context

`SocketConnectionCoordinator` currently drives `LiveSocketService` (Socket.io) connect/disconnect based on three signals: auth state, network connectivity, and app resume. `LiveSessionGrpcService` already handles auth-based connect/disconnect and exponential-backoff reconnect, but lacks connectivity and app-resume awareness. This milestone absorbs the coordinator's remaining lifecycle logic into `LiveSessionGrpcService`, wires the gRPC service into `App.dart` replacing both `LiveSocketService` and `SocketConnectionCoordinator`, and updates all consumers.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Extend LiveSessionGrpcService with connectivity and resume signals

- [x] **Task 1: Add connectivity and resume stream handling to LiveSessionGrpcService**
  Files: `lib/Core/Grpc/LiveSessionGrpcService.dart`
  Add two new constructor parameters: `Stream<List<ConnectivityResult>> connectivityStream` and `Stream<void> resumeStream`. Subscribe to both in the constructor body (after the existing `authStream` subscription). Connectivity handler: on `ConnectivityResult.none` call `disconnect()`; on restore, call `connect()` only if `_isAuthenticated`. Resume handler: call `connect()` if `_isAuthenticated && !isConnected`. Store subscriptions as `late final StreamSubscription` fields. Cancel both in `dispose()` alongside the existing `_authSubscription.cancel()`. Import `package:connectivity_plus/connectivity_plus.dart`. Follow the same log pattern already used (e.g. `log('[LiveSessionGrpc] connectivity lost, disconnecting', name: 'LiveSessionGrpcService')`).

### Phase 2: Wire LiveSessionGrpcService into App.dart and update consumers

- [x] **Task 2: Replace LiveSocketService and SocketConnectionCoordinator in App.dart**
  Files: `lib/Core/App.dart`
  In `initialize()`, replace the `liveSocketService` instantiation (currently `LiveSocketService(storage: const FlutterSecureStorage())`) with a `LiveSessionGrpcService` instantiation passing: `liveService: grpcClient.liveService`, `telemetryService: grpcClient.telemetryService`, `authStream: userNotifier.stream`, `connectivityStream: Connectivity().onConnectivityChanged`, `resumeStream: appLifecycleService.onResume`. Remove the `socketConnectionCoordinator` instantiation line entirely. Update the `App._` field `liveSocketService` from type `LiveSocketService` to `LiveSessionGrpcService` and update the constructor parameter. Remove the `socketConnectionCoordinator` field and constructor parameter. Remove the `LiveSocketService` and `SocketConnectionCoordinator` imports; add the `LiveSessionGrpcService` import. Update all downstream initializers that reference `liveSocketService` — `liveSessionNotifier`, `liveSessionService`, `telemetryService` — they already accept `ILiveSocketService` or `LiveSocketService`; adjust their argument names/types if needed (see Tasks 3-4).

- [x] **Task 3: Update BreathTelemetryService to accept LiveSessionGrpcService**
  Files: `lib/BreathModule/Core/BreathTelemetryService.dart`
  Currently the constructor takes `LiveSocketService` (concrete Socket.io type) and uses `telemetryStateEvents`, `dataAckEvents`, and `emitTelemetry` — all of which exist on `LiveSessionGrpcService` but are not on `ILiveSocketService`. Change the field type and constructor parameter from `LiveSocketService` to `LiveSessionGrpcService`. Update the import from `package:mind/Core/Socket/LiveSocketService.dart` to `package:mind/Core/Grpc/LiveSessionGrpcService.dart`.

- [x] **Task 4: Update SocketDebugOverlay to use LiveSessionGrpcService**
  Files: `lib/Core/Socket/SocketDebugOverlay.dart`
  The overlay reads `App.shared.liveSocketService` (typed as `LiveSocketService`) for `connectionState`, `lastSentMessage`, and `lastReceivedMessage` — all three exist on `LiveSessionGrpcService` with the same signatures. Change the `service` local to read `App.shared.liveSocketService` (no name change needed since the App field keeps the same name). Update the import from `LiveSocketService` to `LiveSessionGrpcService` if the overlay imports the concrete type directly. Since the App field type changes in Task 2, the overlay should compile without further changes — verify the import line references `App.dart` only (it currently does: `import 'package:mind/Core/App.dart'`), so no import change is needed here. Remove the stale `import 'package:mind/Core/Socket/SocketConnectionState.dart'` only if `SocketConnectionState` is already re-exported or imported transitively — keep it if the overlay uses the enum directly (it does, so keep the import).

### Phase 3: Verify GrpcClient exposes required stubs

- [x] **Task 5: Verify GrpcClient has liveService and telemetryService getters**
  Files: `lib/Core/Grpc/GrpcClient.dart`
  Check that `GrpcClient` exposes `LiveServiceClient` as `liveService` and `TelemetryServiceClient` as `telemetryService`. If these getters do not exist, add them following the same lazy-init pattern used by existing stubs (e.g. `authService`, `syncService`). Import the generated `live.pbgrpc.dart` and `telemetry.pbgrpc.dart` if not already imported.
