# Code Review — Extract `GrpcConnectionManager` from `LiveSessionGrpcService`

**Plan:** `39-extract-grpcconnectionmanager-from-livesessiongrpcservice.md`
**Files changed:** 4 (1 new class, 1 new enum, 1 modified, 1 deleted)
**Risk level:** Low

## Static analysis

`flutter analyze` passes with zero issues on all changed files.

## Behavioral equivalence

Traced all five critical flows against the original code:

| Flow | Verdict |
|------|---------|
| `connect()` — guards, state emission, backoff reset, error→disconnect→reconnect | Identical |
| `disconnect()` — cancel timer, cancel handles, emit `disconnected` | Identical (order preserved) |
| Auth listener — authenticated→connect, guest→disconnect | Identical |
| Connectivity listener — none→disconnect, restored→connect | Identical |
| Resume listener — authenticated+disconnected→connect | Identical (`_isConnected()` callback equivalent to old `isConnected` getter) |
| `dispose()` — disconnect, cancel subscriptions, close subjects/controllers | Identical (split across manager + service, same total work) |

## Consumer verification

| Consumer | Accesses | Impact |
|----------|----------|--------|
| `BreathTelemetryService` | `isConnected`, `telemetryStateEvents`, `dataAckEvents`, `emitTelemetry` | None — all remain on `LiveSessionGrpcService` unchanged |
| `LiveBreathSessionNotifier` | `sessionStateEvents`, `sendActivity*` (via `ILiveSessionService`) | None — interface and concrete members unchanged |
| `App.dart` | Constructor call | None — constructor signature unchanged, no import of old enum |

## No issues found

The extraction is clean and mechanically correct. Some notes on things I verified are safe:

1. **`late final _connectionManager` initialization timing.** The `GrpcConnectionManager` constructor subscribes to `authStream`, which (being a `BehaviorSubject`) fires synchronously during `listen()`. This triggers `connect()` on the manager, which calls `await _onConnect()`. The `await` yields to the microtask queue, so the `GrpcConnectionManager` constructor completes, `_connectionManager` assignment finishes, and the `LiveSessionGrpcService` constructor completes — all before the `_onConnect()` future resumes. The `onError`/`onDone` closures in `_openLiveStream()`/`_openTelemetryStream()` reference `_connectionManager` directly, but they only fire asynchronously (on stream errors), by which time the field is assigned.

2. **Double-fire from concurrent stream errors.** If both the live and telemetry streams error at the same time, both `onError` handlers call `_connectionManager.disconnect()` + `_connectionManager.scheduleReconnect()`. The second `disconnect()` is a no-op (handles already null) except for a redundant `disconnected` emission. The second `scheduleReconnect()` replaces the timer (after `disconnect()` cancelled it). This matches the pre-refactor behavior exactly.

3. **`SocketConnectionState` fully removed.** Grep confirms zero references to `SocketConnectionState` remain across the entire repo.

4. **All imports valid.** No unused imports in either changed file. `connectivity_plus` and `AuthState` remain needed in `LiveSessionGrpcService.dart` for the constructor parameter types. `rxdart` correctly moved to `GrpcConnectionManager.dart` only.

REVIEW_PASS
