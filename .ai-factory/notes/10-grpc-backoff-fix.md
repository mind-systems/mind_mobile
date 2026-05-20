# Fix: `confirmConnected()` resets backoff before server data arrives

## Root cause

`GrpcConnectionManager` uses exponential backoff via `_reconnectAttempt`. The counter is reset to 0 by `confirmConnected()`. Both `ModuleStateChannel._openSessionStream()` and `ModuleInstructionStream._openStream()` call `confirmConnected()` immediately after `response.listen()` — before any server data arrives. When the stream fails instantly (e.g. `Connection refused`), `_reconnectAttempt` is already 0, so `_nextDelay()` always returns ~1 s and the backoff never grows.

## Log evidence

```
_openSessionStream() called — attaching listener
calling confirmConnected() — immediately after listen(), no server data yet
confirmConnected() — resetting backoff from attempt 1 → 0       ← reset before error
_resetBackoff: attempt was 1 → 0
session stream error: gRPC Error (code: 14, UNAVAILABLE, ...)
scheduleReconnect: attempt=0 delay=1177ms                        ← always ~1 s
```

`onData` never fires between `attaching listener` and `session stream error`, confirming the server never sends a byte before the connection is refused.

## Fix — `ModuleStateChannel._openSessionStream()`

File: `lib/Core/Grpc/ModuleStateChannel.dart`

Add a `bool _backoffConfirmed = false` field (alongside `_isPendingStart`). Reset it to `false` at the top of `_openSessionStream()`. Move `_connectionManager.confirmConnected()` from the bottom of `_openSessionStream()` into the `onData` callback, guarded so it only fires once per stream open:

```dart
bool _backoffConfirmed = false;

void _openSessionStream() {
  _backoffConfirmed = false;
  _sessionSink = StreamController<proto.StateRequest>();
  final response = _moduleStateService.trackActivity(_sessionSink!.stream);
  _sessionSub = response.listen(
    (proto.StateResponse r) {
      if (!_backoffConfirmed) {
        _backoffConfirmed = true;
        _connectionManager.confirmConnected();   // ← moved here
      }
      switch (r.whichEvent()) { ... }
    },
    onError: (Object e) {
      log('[ModuleStateChannel] session stream error: $e', name: 'ModuleStateChannel');
      _closeSessionStream();
      _connectionManager.disconnect();
      _connectionManager.scheduleReconnect();
    },
    onDone: () {
      log('[ModuleStateChannel] session stream done', name: 'ModuleStateChannel');
      _closeSessionStream();
      _connectionManager.disconnect();
      _connectionManager.scheduleReconnect();
    },
  );
  // confirmConnected() removed from here
}
```

## Fix — `ModuleInstructionStream._openStream()`

File: `lib/Core/Grpc/ModuleInstructionStream.dart`

Same pattern. Add `bool _backoffConfirmed = false` field. Reset it in `_openStream()`. Move `_connectionManager.confirmConnected()` into the `onData` callback:

```dart
bool _backoffConfirmed = false;

void _openStream() {
  _backoffConfirmed = false;
  _streamSink = StreamController<StreamSample>();
  final response = _instructionStreamService.streamData(_streamSink!.stream);
  _streamSub = response.listen(
    (StreamResponse r) {
      if (!_backoffConfirmed) {
        _backoffConfirmed = true;
        _connectionManager.confirmConnected();   // ← moved here
      }
      switch (r.whichEvent()) { ... }
    },
    onError: (Object e) {
      log('[ModuleInstructionStream] stream error: $e', name: 'ModuleInstructionStream');
      _streamRequested = false;
      _connectionManager.disconnect();
      _connectionManager.scheduleReconnect();
    },
    onDone: () {
      log('[ModuleInstructionStream] stream done', name: 'ModuleInstructionStream');
      _streamRequested = false;
      _connectionManager.disconnect();
      _connectionManager.scheduleReconnect();
    },
  );
  // confirmConnected() removed from here
  _readyController.add(null);
}
```

## Diagnostic logs

The following logs were added during debugging and should be removed after the fix is verified:

**`GrpcConnectionManager.dart`** — revert these log messages to their originals:
- `connect() start` — remove the "no TCP handshake" suffix
- `connect() state→connected` — revert to `connect() succeeded`
- Remove the `confirmConnected()` log
- Remove the `_resetBackoff` log
- Revert `scheduleReconnect` log to original format (`reconnecting in Xs (attempt N)`)

**`ModuleStateChannel.dart`** — remove:
- `_openSessionStream() called — attaching listener`
- `onData: event=...`
- `calling confirmConnected() — immediately after listen(), no server data yet`

**`ModuleInstructionStream.dart`** — remove:
- `_openStream() called — attaching listener`
- `onData: event=...`
- `calling confirmConnected() — immediately after listen(), no server data yet`

## Expected behaviour after fix

When the server is unreachable the delay sequence will be:
`~1 s → ~2 s → ~4 s → ~8 s → ... → 30 s (capped)`

`confirmConnected()` fires only after the first real server message, so the counter can only grow when consecutive stream openings fail before delivering any data.
