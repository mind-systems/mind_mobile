# ModuleInstructionStream — Test Plan

**Date:** 2026-06-24
**Source:** roadmap-test-coverage agent

## Source Overview

`ModuleInstructionStream` is the transport-layer adapter for bidirectional gRPC streaming of breath/module instruction samples to the server. It handles the readiness gate (wait for server `ready` before sending), FIFO outbox buffering (pre-ready samples), rate-limiting (max samples/sec), a fallback timer (degrade gracefully if server is un-upgraded), and lifecycle management (reconnect, dispose). It is injected by `BreathModuleInstructionStream` (a thin mapper that converts domain `InstructionSample` DTOs into proto wire format) and by other module instruction streams in future.

## Instantiation

### Constructor Dependencies

```dart
ModuleInstructionStream({
  required GrpcConnectionManager connectionManager,
  required ModuleInstructionStreamServiceClient instructionStreamService,
})
```

**`GrpcConnectionManager`** (mock/fake required):
- Exposes `Stream<GrpcConnectionState> connectionState` (seeded `BehaviorSubject`)
- Defines `void confirmConnected()` — resets backoff counter
- Defines `void disconnect()` — triggers reconnect
- Defines `void scheduleReconnect()` — schedules a delayed retry

**For tests, create a fake:**
- Emit `GrpcConnectionState.connected` at construction to trigger `_openStream()`
- Expose a `StreamController<GrpcConnectionState> connectionStateController` to drive state changes from tests
- Mock `confirmConnected()`, `disconnect()`, `scheduleReconnect()` with spies to verify calls

**`ModuleInstructionStreamServiceClient`** (mock/fake required):
- Implements the gRPC stub method `ResponseStream<StreamResponse> streamData(Stream<StreamSample> request)`
- Must return a `ResponseStream<StreamResponse>` that is listenable (tests wrap it to emit `StreamResponse` objects)

**For tests, create a fake:**
- Store the incoming `Stream<StreamSample> request` for inspection (to verify emitted samples reached the sink)
- Return a `ResponseStream<StreamResponse>` — a wrapper around a `StreamController<StreamResponse>.broadcast()` that tests can populate
- Expose a `StreamController<StreamResponse> responseController` to drive server responses (ready, ack, error)
- Expose `final samples = <StreamSample>[]` to capture all samples written to `request` stream (may require stream-to-list subscription)

### Minimal Setup Boilerplate

```dart
class _FakeConnectionManager implements GrpcConnectionManager {
  final connectionStateController = StreamController<GrpcConnectionState>.broadcast();
  
  @override
  Stream<GrpcConnectionState> get connectionState => connectionStateController.stream;
  
  @override
  GrpcConnectionState get currentState => GrpcConnectionState.connected; // or track manually
  
  @override
  void confirmConnected() { /* spy */ }
  
  @override
  void disconnect() { /* spy */ }
  
  @override
  void scheduleReconnect() { /* spy */ }
  
  // ... other methods as needed
}

class _FakeSampleCapture {
  final samples = <StreamSample>[];
  
  Future<void> recordFromStream(Stream<StreamSample> stream) async {
    await for (final sample in stream) {
      samples.add(sample);
    }
  }
}

class _FakeInstructionStreamServiceClient implements ModuleInstructionStreamServiceClient {
  final responseController = StreamController<StreamResponse>.broadcast();
  final _sampleCapture = _FakeSampleCapture();
  
  @override
  ResponseStream<StreamResponse> streamData(Stream<StreamSample> request, {CallOptions? options}) {
    // Start recording samples in the background
    unawaited(_sampleCapture.recordFromStream(request));
    
    // Return a ResponseStream wrapper (or a custom class that wraps the broadcast stream)
    return _ResponseStreamWrapper(responseController.stream);
  }
  
  List<StreamSample> get recordedSamples => _sampleCapture.samples;
}

// Helper to adapt Stream to ResponseStream interface
class _ResponseStreamWrapper implements ResponseStream<StreamResponse> {
  final Stream<StreamResponse> _stream;
  _ResponseStreamWrapper(this._stream);
  
  @override
  StreamSubscription<StreamResponse> listen(...) => _stream.listen(...);
  // ... implement other ResponseStream methods if needed
}
```

## Existing Coverage

None. The test file `test/BreathModule/breath_module_state_channel_test.dart` uses a `_FakeInstructionStream` that implements only the domain-level `BreathModuleInstructionStream` interface. The real `ModuleInstructionStream` class is never instantiated or unit-tested.

## Test Cases

### Group 1: Construction and Connection State Changes

#### 1.1 should construct without throwing
- **Setup:** Inject fakes, do NOT emit any connection state.
- **Action:** Call constructor.
- **Verify:** Instance is non-null, `_streamSink` is null (no stream opened until connection).

#### 1.2 should open stream immediately when GrpcConnectionState.connected is emitted at construction
- **Setup:** Fake connection manager emits `GrpcConnectionState.connected` from its seeded stream.
- **Action:** Construct `ModuleInstructionStream`.
- **Verify:** `isConnected` returns `true`, `_streamSink` is non-null.

#### 1.3 should reset _isReady, _lastSendTime, and clear outbox on every _openStream call (cold-start and reconnect)
- **Setup:** Construct with connected state, emit a sample (buffered in outbox), drive server `ready`.
- **Action:** Emit `GrpcConnectionState.disconnected`, then emit `GrpcConnectionState.connected` again (reconnect).
- **Verify:** `_isReady == false` (re-armed), `_lastSendTime == null`, `_outbox.isEmpty`.
- **Note:** _isReady and _lastSendTime are private; verify indirectly by checking that pre-ready samples are buffered again and rate-limit counter resets.

#### 1.4 should cancel readiness timer on disconnect
- **Setup:** Construct with connected state, let fallback timer start (5 s).
- **Action:** Emit `GrpcConnectionState.disconnected` before timer fires.
- **Verify:** Timer does not fire (no forced ready flush logged).
- **Note:** Requires spy on `_readyTimer` or checking log output.

#### 1.5 should clear outbox and reset ready flag on disconnect
- **Setup:** Construct, emit sample (buffered), emit `GrpcConnectionState.connected`.
- **Action:** Emit `GrpcConnectionState.disconnected`.
- **Verify:** Outbox is cleared, `_isReady == false`, no samples sent to sink.

---

### Group 2: Readiness Gate and Outbox Buffering

#### 2.1 should buffer samples in outbox when _isReady is false
- **Setup:** Construct, open stream (but do NOT emit `ready` from server).
- **Action:** Call `emit(sample1)`, `emit(sample2)`.
- **Verify:** Samples do NOT reach the gRPC sink (verify via fake stub spy), outbox contains two items in FIFO order.
- **Note:** Requires inspection of private `_outbox` or indirect verification (e.g., no samples captured by fake stub yet).

#### 2.2 should drain outbox into sink (FIFO) when StreamResponse_Event.ready is received
- **Setup:** Construct, emit sample (buffered in outbox before ready), set up fake to capture outbox.
- **Action:** Emit `StreamResponse_Event.ready` from server.
- **Verify:** Samples are drained into `_streamSink` in FIFO order (sorted by timestamp if proto carries it).
- **Note:** The code at line 174 sorts `_outbox` by timestamp before draining — verify order matches sorted order, not emission order.

#### 2.3 should set _isReady=true on ready, allowing subsequent emits to bypass outbox
- **Setup:** Construct, emit sample (buffered), emit `ready` (outbox drained).
- **Action:** Emit second sample after ready.
- **Verify:** Second sample reaches sink immediately, not buffered.

#### 2.4 should fire _readyController after draining outbox
- **Setup:** Construct, emit sample (buffered).
- **Action:** Emit `ready` from server.
- **Verify:** `_readyController` fires, allowing any domain listeners to flush their own buffers.
- **Note:** `_readyController` is private; verify indirectly by checking that domain-level `flushBuffer()` is triggered or by spying on the domain layer's corresponding listener.

---

### Group 3: Fallback Timer (Un-Upgraded Server Graceful Degradation)

#### 3.1 should start fallback timer in _openStream
- **Setup:** Construct with connected state, trigger `_openStream()`.
- **Action:** Observe timer setup.
- **Verify:** Timer is scheduled for 5 seconds.
- **Note:** Use spy on `Timer` or mock time (if testing with `FakeAsync`).

#### 3.2 should flush and set _isReady=true when fallback timer fires (5s timeout without ready)
- **Setup:** Construct, emit sample (buffered).
- **Action:** Wait 5 seconds without server emitting `ready`.
- **Verify:** `_isReady == true`, outbox drained, sample reached sink, log message emitted ("readiness timeout — flushing without server ready").
- **Note:** Requires `FakeAsync` or a way to advance time. Without it, this test may need to be integration-style.

#### 3.3 should cancel fallback timer when ready is received before timeout
- **Setup:** Construct, start timer.
- **Action:** Emit `ready` within 5 seconds.
- **Verify:** Timer is cancelled (verified via spy or by checking no additional log lines appear after ready).

#### 3.4 should cancel fallback timer on stream error
- **Setup:** Construct, start timer.
- **Action:** Emit stream error via fake stub.
- **Verify:** Timer is cancelled, `_isReady == false`, outbox cleared, `disconnect()` and `scheduleReconnect()` called on connection manager.

#### 3.5 should cancel fallback timer on stream done
- **Setup:** Construct, start timer.
- **Action:** Close response stream (via fake stub `responseController.close()`).
- **Verify:** Timer is cancelled, `_isReady == false`, outbox cleared, `disconnect()` and `scheduleReconnect()` called.

---

### Group 4: Rate-Limiting

#### 4.1 should drop samples when emitting faster than _maxSamplesPerSecond
- **Setup:** Construct, emit `ready`.
- **Action:** Call `emit(sample1)`, immediately call `emit(sample2)` (< minIntervalMs apart, where minIntervalMs = 1000 / maxSamplesPerSecond).
- **Verify:** `sample2` is dropped (log message "over-cap, dropping sample"), only `sample1` reaches sink.
- **Note:** Default `_maxSamplesPerSecond = 10`, so minIntervalMs = 100. Emit two samples 50ms apart to trigger drop.

#### 4.2 should allow samples spaced >= minIntervalMs apart
- **Setup:** Construct, emit `ready`.
- **Action:** Call `emit(sample1)`, advance time >= minIntervalMs, call `emit(sample2)`.
- **Verify:** Both samples reach sink.

#### 4.3 should reset rate-limit counters on disconnect
- **Setup:** Construct, emit sample1 (sets `_lastSendTime`).
- **Action:** Emit `GrpcConnectionState.disconnected`, then `GrpcConnectionState.connected` (reconnect).
- **Verify:** `_lastSendTime == null`, rate-limit counter reset (next sample does not check interval against old timestamp).

#### 4.4 should update _maxSamplesPerSecond from StreamResponse_Event.ack
- **Setup:** Construct, emit `ready`.
- **Action:** Emit `StreamAck` with `maxSamplesPerSecond = 5`.
- **Verify:** `_maxSamplesPerSecond == 5`, minIntervalMs now = 200.

#### 4.5 should update _maxSamplesPerSecond from StreamResponse_Event.ready
- **Setup:** Construct, do NOT emit ready yet.
- **Action:** Emit `StreamReady` with `maxSamplesPerSecond = 20`.
- **Verify:** `_maxSamplesPerSecond == 20`, ready sets true, subsequent emits use new rate limit.

---

### Group 5: Proto Conversion and Data Mapping

#### 5.1 should convert InstructionSample to StreamSample proto
- **Setup:** Construct, emit ready.
- **Action:** Call `emit(InstructionSample(sessionId: 'sess1', timestamp: 12345, moduleId: 'breath', instructionType: 'breath_phase', data: {...}))`.
- **Verify:** Fake stub captures a `StreamSample` with matching fields.

#### 5.2 should map scalar data types (string, int, double, bool) to protobuf Value
- **Setup:** Construct, emit ready.
- **Action:** Emit sample with `data: {'str': 'hello', 'int': 42, 'double': 3.14, 'bool': true}`.
- **Verify:** Proto `Struct.fields` contains correct `Value` types (stringValue, numberValue, boolValue).

#### 5.3 should map null values to NullValue.NULL_VALUE
- **Setup:** Construct, emit ready.
- **Action:** Emit sample with `data: {'nullable': null}`.
- **Verify:** Proto carries `nullValue: NullValue.NULL_VALUE`.

#### 5.4 should map nested maps to protobuf Struct recursively
- **Setup:** Construct, emit ready.
- **Action:** Emit sample with `data: {'outer': {'inner': 'value'}}`.
- **Verify:** Proto carries nested `Struct` with correct hierarchy.

#### 5.5 should map lists to protobuf ListValue
- **Setup:** Construct, emit ready.
- **Action:** Emit sample with `data: {'items': [1, 'two', 3.0]}`.
- **Verify:** Proto carries `ListValue` with three `Value` entries (number, string, number).

#### 5.6 should throw ArgumentError for unsupported types (e.g., custom objects)
- **Setup:** Construct, emit ready.
- **Action:** Call `emit(sample)` with `data: {'custom': DateTime.now()}`.
- **Verify:** ArgumentError is thrown.

---

### Group 6: Backoff Confirmation

#### 6.1 should call confirmConnected() once per stream open on first response
- **Setup:** Construct, set up fake to emit `ack` as the first response.
- **Action:** Emit `StreamAck`.
- **Verify:** `confirmConnected()` called exactly once, `_backoffConfirmed` set to true.

#### 6.2 should not call confirmConnected() again on subsequent responses
- **Setup:** Construct, receive one `ack`, then receive second `ack`.
- **Action:** Emit two `StreamAck` messages.
- **Verify:** `confirmConnected()` called exactly once (from first ack).

#### 6.3 should call confirmConnected() on ready if that is the first response
- **Setup:** Construct, set up fake to emit `ready` as the first response.
- **Action:** Emit `StreamReady`.
- **Verify:** `confirmConnected()` called exactly once.

---

### Group 7: Error Handling

#### 7.1 should log error message when StreamResponse_Event.error is received
- **Setup:** Construct, emit ready.
- **Action:** Emit `StateErrorEvent` with code=123, message="test error".
- **Verify:** Log line "error: 123 — test error" appears.

#### 7.2 should call disconnect() and scheduleReconnect() on stream error
- **Setup:** Construct.
- **Action:** Trigger stream `onError` callback with an exception.
- **Verify:** `disconnect()` called, `scheduleReconnect()` called, `_isReady == false`, outbox cleared.

#### 7.3 should call disconnect() and scheduleReconnect() on stream done
- **Setup:** Construct.
- **Action:** Close the response stream normally (via fake).
- **Verify:** `disconnect()` called, `scheduleReconnect()` called.

---

### Group 8: Public API — emit() Edge Cases

#### 8.1 should open stream lazily when emit() is called and _streamSink is null
- **Setup:** Construct, but do NOT transition to connected state yet.
- **Action:** Emit `GrpcConnectionState.disconnected` (stay disconnected), call `emit(sample)`.
- **Verify:** Stream is not opened, sample is dropped, log "not connected, dropping sample" appears.

#### 8.2 should open stream on emit() if connected but stream not yet open
- **Setup:** Construct with connected state.
- **Action:** Call `emit(sample)` (no manual open).
- **Verify:** Stream opens, `_streamSink` becomes non-null.

#### 8.3 should buffer sample if stream is open but _isReady is false
- **Setup:** Construct, emit `ready`, then manually close stream without disconnecting (edge case).
- **Action:** Call `emit(sample)`.
- **Verify:** Stream reopens, sample is buffered (since ready flag was reset on reopen).

---

### Group 9: Dispose and Cleanup

#### 9.1 should cancel readiness timer on dispose
- **Setup:** Construct, let timer start.
- **Action:** Call `dispose()` before timer fires.
- **Verify:** Timer cancelled (no forced ready flush).

#### 9.2 should cancel connection state subscription on dispose
- **Setup:** Construct.
- **Action:** Call `dispose()`, then emit connection state change.
- **Verify:** No side effects (stream not reopened).

#### 9.3 should close stream sink on dispose
- **Setup:** Construct, emit ready.
- **Action:** Call `dispose()`.
- **Verify:** `_streamSink.close()` called.

#### 9.4 should cancel stream subscription on dispose
- **Setup:** Construct.
- **Action:** Call `dispose()`.
- **Verify:** `_streamSub` cancelled, no further responses trigger handlers.

#### 9.5 should set internal state to null on dispose
- **Setup:** Construct, emit ready.
- **Action:** Call `dispose()`.
- **Verify:** `_streamSink == null`, `_streamSub == null`.

#### 9.6 should be idempotent (calling dispose() twice is safe)
- **Setup:** Construct.
- **Action:** Call `dispose()`, then call `dispose()` again.
- **Verify:** No exceptions thrown, internal state remains null.

---

## Gotchas

### Timers and FakeAsync
- The fallback timer is a real `Timer`. Tests that check timeout behavior need either:
  - `FakeAsync` from `package:fake_async` (wrap test body, use `fakeAsync.elapse()` to advance time)
  - Or skip the timeout test and rely on integration tests
  - The 5-second timeout is hardcoded; mock time accordingly.

### gRPC Stub Teardown
- `ResponseStream<StreamResponse>` is a listenable stream, not a `StreamController` directly.
- Closing the fake controller will trigger `onDone` on the subscription. Tests must handle this gracefully.
- If a test manually closes the response controller, it will trigger error handling paths; verify this is intentional.

### Fire-and-Forget Async
- The sample capture loop (`recordFromStream(request)`) is awaited asynchronously (`unawaited` pattern).
- If a test checks `recordedSamples` immediately after `emit()`, the sample may not have arrived yet (await a microtask with `Future<void>.delayed(Duration.zero)` first).

### Private Fields
- `_isReady`, `_lastSendTime`, `_outbox`, `_backoffConfirmed`, `_readyTimer` are all private.
- Tests verify them indirectly via observable side effects (log output, sink behavior, rate-limit behavior).
- Consider adding a test-only getter (e.g., `@visibleForTesting bool get isReadyForTest => _isReady;`) if indirection becomes unwieldy, but prefer indirect verification first.

### Re-Arm Invariant
- The `_isReady` flag and `_outbox` must reset on **every** `_openStream()` call, not just cold-start.
- Tests that verify reconnect paths must confirm this — emit sample, ready, disconnect, reconnect, emit again → second sample should buffer (not send directly).

### Connection State Seeding
- The fake `GrpcConnectionManager.connectionState` must be a `BehaviorSubject` (or equivalent seeded stream) so the constructor's listener immediately receives the initial state.
- If the stream is cold (not seeded), the constructor will not trigger `_openStream()` and tests will fail silently.

### Outbox Sort by Timestamp
- Line 174 sorts the outbox by timestamp before draining. Tests must populate `InstructionSample.timestamp` fields to verify order.
- If all samples have `timestamp: 0`, sort is stable but invisible — vary timestamps to confirm ordering.

### Rate-Limit Edge Cases
- The rate-limit uses `DateTime.now()` for wall-clock timing. Tests must either:
  - Mock `DateTime` (requires a testing library like `clock`), or
  - Use `FakeAsync` to control time, or
  - Accept that the limit is "best-effort" and test it in integration mode.
- The logic at line 87 compares `difference(_lastSendTime!).inMilliseconds < minIntervalMs`; if two calls happen in the same millisecond, they will both pass (edge case).

## Refactor Required

**What to refactor:** Add a `DateTime Function() clock` constructor parameter (default `DateTime.now`) to `ModuleInstructionStream`. Replace the two `DateTime.now()` calls in `emit()` with `clock()`.

**Post-refactor API:**
```dart
ModuleInstructionStream(
  GrpcConnectionManager connectionManager,
  ModuleInstructionStreamServiceClient grpcStub, {
  DateTime Function() clock = DateTime.now,
})
```

**What the test implementer gets:** Deterministic rate-limit tests — inject a fake clock that returns a fixed value so `_lastSendTime` comparison is controllable without real waits. All other dependencies (gRPC stub, connection-manager) are already injected.
