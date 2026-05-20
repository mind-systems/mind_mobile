# Plan: Fix `confirmConnected()` resetting backoff before server data arrives

## Context
`ModuleStateChannel._openSessionStream()` and `ModuleInstructionStream._openStream()` call `_connectionManager.confirmConnected()` immediately after attaching the response listener — before any server message arrives. This resets `_reconnectAttempt` to 0 even when the underlying gRPC stream immediately fails (e.g. `Connection refused`), so `_nextDelay()` always returns ~1 s and exponential backoff never grows. Move the `confirmConnected()` call into the `onData` callback, gated by a per-stream-open `_backoffConfirmed` flag, so the backoff is only reset after the first real server message. Also remove any diagnostic logs added during the investigation.

Full diagnosis and exact code references: `.ai-factory/notes/10-grpc-backoff-fix.md`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Fix backoff confirmation timing

- [x] **Task 1: Gate `confirmConnected()` in `ModuleStateChannel`**
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Add a `bool _backoffConfirmed = false` field next to the other pending guards (alongside `_isPendingStart` / `_isPendingPause`). In `_openSessionStream()`:
  - Reset `_backoffConfirmed = false` at the top of the method (right before constructing `_sessionSink`).
  - Remove the existing `_connectionManager.confirmConnected();` call at the bottom of `_openSessionStream()`.
  - Inside the `onData` handler (the `(proto.StateResponse r) { ... }` block), before the `switch (r.whichEvent())`, add:
    ```dart
    if (!_backoffConfirmed) {
      _backoffConfirmed = true;
      _connectionManager.confirmConnected();
    }
    ```
  Do not modify `onError`, `onDone`, `_closeSessionStream()`, or any other behaviour. The `confirmConnected()` call must fire exactly once per stream open, only after the server has sent at least one byte.

- [x] **Task 2: Gate `confirmConnected()` in `ModuleInstructionStream`** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleInstructionStream.dart`
  Add a `bool _backoffConfirmed = false` field next to the other lazy-connect flags (alongside `_isGrpcConnected` / `_streamRequested`). In `_openStream()`:
  - Reset `_backoffConfirmed = false` at the top of the method (right before constructing `_streamSink`).
  - Remove the existing `_connectionManager.confirmConnected();` call near the bottom of `_openStream()`.
  - Keep the `_readyController.add(null);` call exactly where it is (it must still fire synchronously after `listen()` so emitters know the sink is ready).
  - Inside the `onData` handler (the `(StreamResponse r) { ... }` block), before the `switch (r.whichEvent())`, add:
    ```dart
    if (!_backoffConfirmed) {
      _backoffConfirmed = true;
      _connectionManager.confirmConnected();
    }
    ```
  Do not modify `onError`, `onDone`, or proto conversion helpers.

### Phase 2: Revert diagnostic logs

- [x] **Task 3: Verify and clean diagnostic logs in `GrpcConnectionManager`** (depends on Task 2)
  Files: `lib/Core/Grpc/GrpcConnectionManager.dart`
  Confirm the file matches the pre-investigation baseline and remove any leftover diagnostic logs. Specifically:
  - `connect()` should log only `connect() start` (no `— no TCP handshake` suffix) and `connect() succeeded` (not `connect() state→connected`).
  - `confirmConnected()` must contain no `log(...)` call — it should only call `_resetBackoff()`.
  - `_resetBackoff()` must contain no `log(...)` call — only `_reconnectAttempt = 0;`.
  - `_scheduleReconnectInternal()` should log `'[GrpcConnectionManager] reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempt)'` (the original format).
  Inspect the file and remove any deviation from that baseline; leave existing non-diagnostic logs untouched.

- [x] **Task 4: Verify and clean diagnostic logs in `ModuleStateChannel`** (depends on Task 3)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Confirm and remove any of the following diagnostic logs if present anywhere in the file (most likely inside `_openSessionStream()` or its `onData` handler):
  - `'_openSessionStream() called — attaching listener'`
  - `'onData: event=...'` (any log starting with `onData:`)
  - `'calling confirmConnected() — immediately after listen(), no server data yet'`
  Keep the existing non-diagnostic logs (`session stream error`, `session stream done`, `session error: ...`, `unhandled status: ...`, `not connected, dropping request`) untouched.

- [x] **Task 5: Verify and clean diagnostic logs in `ModuleInstructionStream`** (depends on Task 4)
  Files: `lib/Core/Grpc/ModuleInstructionStream.dart`
  Confirm and remove any of the following diagnostic logs if present anywhere in the file (most likely inside `_openStream()` or its `onData` handler):
  - `'_openStream() called — attaching listener'`
  - `'onData: event=...'` (any log starting with `onData:`)
  - `'calling confirmConnected() — immediately after listen(), no server data yet'`
  Keep the existing non-diagnostic logs (`stream error: ...`, `stream done`, `error: ...`, `not connected, dropping sample`) untouched.

## Commit Plan
- **Commit 1** (after tasks 1-2): "Gate confirmConnected() behind first server message in module streams"
- **Commit 2** (after tasks 3-5): "Remove leftover diagnostic logs from gRPC connection investigation"
