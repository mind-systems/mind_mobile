# Plan: Eager-open data tunnels at connect (instruction + biometric)

## Context
Make both data tunnels (`ModuleInstructionStream`, `BiometricStreamClient`) mirror the already-eager state tunnel: open on `GrpcConnectionState.connected`, stay open for the app lifetime, reopen on reconnect. The readiness gate (notes 114/115), the biometric session gate, and the 2 s reopen cooldown are all preserved unchanged — only *when* the sink opens changes.

## Settings
- Testing: no
- Logging: minimal (`logPrint` only — never `print`/`debugPrint`/`dart:developer`)
- Docs: no

## Reference patterns (already in the codebase)
- `lib/Core/Grpc/ModuleStateChannel.dart` — the model to mirror: its `_connectionSub` calls `_openSessionStream()` on `connected` and `_closeSessionStream()` on `disconnected`, with no lazy/request gate. Both data tunnels should match this lifecycle shape.
- `GrpcConnectionManager.connectionState` (`Stream<GrpcConnectionState>`, BehaviorSubject-seeded) is the connection-state source. `ModuleInstructionStream` already receives the manager; `BiometricStreamClient` does not yet.

## Tasks

### Phase 1: Eager-open instruction tunnel

- [x] **Task 1: Open `ModuleInstructionStream` eagerly on connect**
  Files: `lib/Core/Grpc/ModuleInstructionStream.dart`
  In the `_connectionSub` listener `GrpcConnectionState.connected` case, call `_openStream()` unconditionally (currently `if (_streamRequested) _openStream()`). Remove the `_streamRequested` field and all of its assignments — the lazy-request gate is gone:
  - In `emit()`: drop the `_streamRequested = true;` line. Keep the `_streamSink == null` safety fallback (the `!_isGrpcConnected` drop-with-log path and the `_openStream()` re-open path) so a sample arriving before the eager open still works; in steady state the sink is already open at connect.
  - In `_openStream()`'s `onError` and `onDone` handlers: remove the `_streamRequested = false;` lines.
  Do NOT touch the readiness gate: `_isReady`, `_outbox`, `_readyTimer`, `_becomeReady()`, `_drainOutbox()`, `_onReadyTimeout()` stay exactly as-is. `_openStream()` already re-arms the gate (resets `_isReady`, clears `_outbox`, restarts `_readyTimer`) on every call, so reconnect correctness is preserved. The `disconnected` case (cancel timer, reset `_isReady`, clear `_outbox`, tear down sub/sink) stays unchanged.

### Phase 2: Eager-open biometric tunnel

- [x] **Task 2: Drive `BiometricStreamClient` sink from connection state**
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  Inject the connection-state stream and open/close the sink on it, mirroring the state tunnel:
  - Add constructor param `required Stream<GrpcConnectionState> connectionState` alongside the existing `moduleStateEvents`. Add `import 'package:mind/Core/Grpc/GrpcConnectionState.dart';`.
  - Add a `late final StreamSubscription<GrpcConnectionState> _connectionSub;` field and subscribe in the constructor body. Handler: on `connected` → `_ensureSinkOpen()`; on `disconnected` → `_teardownSink()`; on `connecting` → no-op (use a `switch` over `GrpcConnectionState`, matching `ModuleStateChannel`).
  - In `dispose()`: `await _connectionSub.cancel();` before the other cancels.
  - Preserve everything else exactly: the `sendBatch` session gate (`_currentSessionId == null || _isPaused` → no-op), the 2 s reopen cooldown (`_lastOpenAttempt`) inside `_ensureSinkOpen()`, the readiness gate (`_isReady`, `_readyTimer`, the 5 s fallback drain), and the replay ring. `_ensureSinkOpen()` already re-arms `_isReady = false` on each open, so the gate re-arms per open for both cold-start and reconnect.
  - Result: the sink opens at connect and is idle (no samples) until a session starts, because `_encodeAndAdd()` still early-returns when `_currentSessionId == null`. No change to the no-samples-without-session rule.

### Phase 3: Wiring

- [x] **Task 3: Pass `connectionState` into `BiometricStreamClient` in `App.dart`** (depends on Task 2)
  Files: `lib/Core/App.dart`
  Update the `BiometricStreamClient(...)` construction (around line 215) to pass `connectionState: connectionManager.connectionState` in addition to the existing `grpcStub` and `moduleStateEvents` args. The `connectionManager` is already built earlier in the same method (line 206), so no reordering is needed. Follow the existing single-line, no-trailing-comma initializer style used for the other `App.dart` constructions.

## Verify (manual, per spec note 116)
- Launch the app with no session → server `Realtime metrics: connectedStreams` shows all three tunnels (state + instruction + biometric) connected; data controllers' subscription is live before any session.
- Start a breath session → first `rest` phase ships with no open-latency; instruction outbox empty at send time.
- Force a reconnect mid-session → all tunnels reopen on `connected`; the readiness gate buffers across the gap; nothing dropped.
