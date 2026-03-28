# Plan: Extract `GrpcConnectionManager` from `LiveSessionGrpcService`

## Context

`LiveSessionGrpcService` currently owns two concerns: (1) gRPC connection lifecycle (connect / disconnect / exponential backoff / auth + connectivity + resume listeners) and (2) live-session + telemetry stream protocol logic. This milestone extracts concern (1) into a standalone `GrpcConnectionManager` in `lib/Core/Grpc/`, renames `SocketConnectionState` to `GrpcConnectionState`, and makes `LiveSessionGrpcService` delegate all connection lifecycle to the new manager.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Rename enum and create the new class

- [x] **Task 1: Rename `SocketConnectionState` to `GrpcConnectionState`**
  Files: `lib/Core/Grpc/SocketConnectionState.dart` (rename to `GrpcConnectionState.dart`), `lib/Core/Grpc/LiveSessionGrpcService.dart`
  Rename the file `SocketConnectionState.dart` → `GrpcConnectionState.dart` and rename the enum inside from `SocketConnectionState` to `GrpcConnectionState`. Update the import and all references in `LiveSessionGrpcService.dart` (6 occurrences: the import, the BehaviorSubject type, the seeded value, the getter return type, and the three `.add()` calls emitting `connecting`/`connected`/`disconnected`). No other files import this enum — only `LiveSessionGrpcService` references it.

  The name `GrpcConnectionState` is chosen over plain `ConnectionState` to avoid collision with Flutter's `ConnectionState` in `package:flutter/widgets.dart`.

- [x] **Task 2: Create `GrpcConnectionManager` class**
  Files: `lib/Core/Grpc/GrpcConnectionManager.dart` (new)
  Create a new class that owns all connection lifecycle logic currently embedded in `LiveSessionGrpcService`. Extract these responsibilities:

  **Constructor parameters** (all injected — follows the project rule "all dependencies via constructor"):
  - `Stream<AuthState> authStream`
  - `Stream<List<ConnectivityResult>> connectivityStream`
  - `Stream<void> resumeStream`
  - `Future<void> Function() onConnect` — callback the manager invokes when it decides a connection should be established
  - `void Function() onDisconnect` — callback invoked when the manager decides to tear down
  - `bool Function() isConnected` — callback to check if the underlying transport is alive (avoids the manager tracking stream subscription state it doesn't own)

  **State and streams to move from `LiveSessionGrpcService`:**
  - `BehaviorSubject<GrpcConnectionState> _connectionState` (seeded `disconnected`) → exposed as `Stream<GrpcConnectionState> get connectionState`
  - `GrpcConnectionState get currentState` (synchronous read of the BehaviorSubject value)
  - `bool _isConnecting` mutex flag
  - `bool _isAuthenticated` flag
  - `Timer? _reconnectTimer`, `int _reconnectAttempt`
  - Constants `_initialDelay` (1s), `_maxDelay` (30s)

  **Listener subscriptions to move (all `late final`, wired in constructor):**
  - `_authSubscription`: on `AuthenticatedState` → set `_isAuthenticated = true`, call `connect()`; on `GuestState` → set `_isAuthenticated = false`, call `disconnect()`
  - `_connectivitySubscription`: `ConnectivityResult.none` → `disconnect()`; otherwise if authenticated → `connect()`
  - `_resumeSubscription`: if authenticated and not connected → `connect()`

  **Methods to move:**
  - `Future<void> connect()` — guards (`isConnected() || _isConnecting`), sets `_isConnecting`, emits `connecting`, calls `await onConnect()`, on success emits `connected` + `_resetBackoff()`, on failure calls `disconnect()` + `_scheduleReconnect()`; `finally` clears `_isConnecting`. Return type is explicitly `Future<void>`.
  - `void disconnect()` — cancels reconnect timer, calls `onDisconnect()`, emits `disconnected`, sets `_isConnecting = false`
  - `void scheduleReconnect()` — **public**, so transport-level stream errors in `LiveSessionGrpcService` can trigger reconnect from outside. Calls `_scheduleReconnectInternal()`.
  - `Duration _nextDelay()`, `void _scheduleReconnectInternal()`, `void _resetBackoff()` — unchanged exponential backoff with jitter logic (moved from `LiveSessionGrpcService`)
  - `void dispose()` — calls `disconnect()`, cancels all three subscriptions, closes `_connectionState`

  Log tag: `[GrpcConnectionManager]`.

### Phase 2: Refactor `LiveSessionGrpcService` to delegate

- [x] **Task 3: Slim down `LiveSessionGrpcService` to use `GrpcConnectionManager`** (depends on Tasks 1-2)
  Files: `lib/Core/Grpc/LiveSessionGrpcService.dart`

  **Design:** `LiveSessionGrpcService` keeps its existing constructor parameters (`authStream`, `connectivityStream`, `resumeStream`) and creates `GrpcConnectionManager` internally in the constructor body, passing `_connect`, `_disconnect`, and `() => isConnected` as callbacks alongside the three streams. This avoids a circular dependency at construction time and keeps `_connect`/`_disconnect` private. No changes to `App.dart` are needed since the constructor signature is unchanged.

  **Remove from `LiveSessionGrpcService`:**
  - Fields: `_connectionState`, `_isAuthenticated`, `_isConnecting`, `_reconnectTimer`, `_reconnectAttempt`, `_initialDelay`, `_maxDelay`
  - Listener subscriptions: `_authSubscription`, `_connectivitySubscription`, `_resumeSubscription`
  - Methods: `_nextDelay()`, `_scheduleReconnect()`, `_resetBackoff()`

  **Add:**
  - `late final GrpcConnectionManager _connectionManager` — created in constructor body after the initializer list

  **Rewire `connect()` and `disconnect()`:**
  - Turn `connect()` into a private `Future<void> _connect()` that only does `Future.wait([_openLiveStream(), _openTelemetryStream()])` — no guards, no state emission, no backoff (the manager handles all that)
  - Turn `disconnect()` into a private `void _disconnect()` that only cancels/nulls the four stream handles (`_liveSub`, `_telemetrySub`, `_liveSink`, `_telemetrySink`) — no state emission, no reconnect timer

  **Constructor body:**
  ```dart
  _connectionManager = GrpcConnectionManager(
    authStream: authStream,
    connectivityStream: connectivityStream,
    resumeStream: resumeStream,
    onConnect: _connect,
    onDisconnect: _disconnect,
    isConnected: () => isConnected,
  );
  ```

  **Delegate public surface:**
  - `Stream<GrpcConnectionState> get connectionState` → forward from `_connectionManager.connectionState`
  - `bool get isConnected` → keep the existing `_liveSub != null && _telemetrySub != null` check (also provided to the manager as `isConnected` callback)

  **`dispose()`:** call `_connectionManager.dispose()` (which internally calls `_disconnect()` via callback), then close `_sessionStateController`, `_telemetryStateController`, `_dataAckController`.

  **Stream error/done handlers** in `_openLiveStream()` and `_openTelemetryStream()`: currently call `disconnect()` then `_scheduleReconnect()`. Change them to call `_connectionManager.disconnect()` followed by `_connectionManager.scheduleReconnect()`.

- [x] **Task 4: Verify build and consumers** (depends on Task 3)
  Files: `lib/Core/Grpc/LiveSessionGrpcService.dart`, `lib/Core/Grpc/GrpcConnectionManager.dart`, `lib/Core/Grpc/GrpcConnectionState.dart`, `lib/Core/App.dart`

  Run `flutter analyze` from the project root to confirm zero errors.

  **Verify `App.dart`:** Since `LiveSessionGrpcService` keeps the same constructor signature (still receives `authStream`, `connectivityStream`, `resumeStream`), `App.dart` should require no changes. Confirm it compiles. `App.dart` does not import `SocketConnectionState` today, so no import update is needed.

  **Verify `BreathTelemetryService`:** `BreathTelemetryService` (`lib/BreathModule/Core/BreathTelemetryService.dart`) is a direct consumer of `LiveSessionGrpcService` — it accesses `isConnected` (line 55), `telemetryStateEvents` (line 19), and `dataAckEvents` (line 20). All three remain on `LiveSessionGrpcService` and are unaffected by this refactor. Confirm no breakage.

  **Verify `LiveBreathSessionNotifier`:** another consumer that receives `LiveSessionGrpcService` as `liveSessionService` — confirm its usage is unaffected.

  Delete the old `SocketConnectionState.dart` file if the rename in Task 1 was done by creating a new file + deleting the old one (rather than `git mv`). Ensure no stale imports remain.

## Commit Plan
- **Commit 1** (after tasks 1-4): "Extract GrpcConnectionManager from LiveSessionGrpcService, rename SocketConnectionState to GrpcConnectionState"
