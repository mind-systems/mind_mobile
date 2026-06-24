# BiometricStreamClient — Test Plan

**Date:** 2026-06-24
**Source:** roadmap-test-coverage agent

## Source Overview

`BiometricStreamClient` (`lib/Biometrics/BiometricStreamClient.dart`) is the gRPC sink for the biometric pipeline. It:

1. **Opens and manages a bidirectional gRPC stream** (`ModuleBiometricStreamService.streamData`) to send `BioSampleBatch` messages to the server.
2. **Buffers samples on send failure** into a bounded drop-oldest replay ring (max 75 samples). On stream reconnect, the ring drains first before new samples are pushed.
3. **Enforces readiness gating** — samples are enqueued to replay until the server emits a `BioStreamResponse.ready` frame or a 5-second fallback timer fires.
4. **Gates sends on session liveness** — `sendBatch` is a no-op when there is no active session (`_currentSessionId == null`) or the session is unconfirmed (`!_sessionConfirmed`).
5. **Pauses do not suppress sends** — the only gate is session liveness (`_currentSessionId != null`). Samples flow through pause (note 123).
6. **Enforces a 2-second reopen cooldown** — repeated `_ensureSinkOpen` calls within 2 seconds are dropped to avoid thrashing.
7. **Responds to lifecycle events** — `ModuleSessionStarted`/`ModuleSessionResumed` set `_sessionConfirmed = true`; `ModuleSessionEnded`/`ModuleSessionAbandoned` clear session and replay ring.
8. **Responds to connection state** — on `connected`, calls `_ensureSinkOpen()` (eager-open); on `disconnected`, tears down sink and sets `_sessionConfirmed = false`.

## Instantiation

Construct the client with (all parameters named, lines 61–66 of `BiometricStreamClient.dart`):
```dart
final client = BiometricStreamClient(
  grpcStub: mockGrpcStub,
  moduleStateEvents: lifecycleController.stream,
  connectionState: connectionController.stream,
  clock: () => DateTime.now(),  // optional; default: DateTime.now
  readyTimeout: const Duration(seconds: 5),  // optional; default: 5s
);
```

**Fakes needed:**

- **`$bio.ModuleBiometricStreamServiceClient` (gRPC stub):** Mock `streamData(Stream<$bio.BioSampleBatch> input)` to return a `Stream<$bio.BioStreamResponse>`. Spy on calls and capture the input stream controller for test injection of server responses.
- **`ModuleStateEvent` stream:** Use a `StreamController<ModuleStateEvent>` to emit lifecycle events (session started, resumed, paused, ended, abandoned).
- **`GrpcConnectionState` stream:** Use a `StreamController<GrpcConnectionState>` to emit connection state changes (connecting, connected, disconnected).
- **`BioSample`:** Use factories (`BioSample.fromCardio`, etc.) or construct directly with `const BioSample(timestampMs: 123, sampleType: 'rr', data: {...})`.
- **Logging:** Mock or suppress `logPrint` calls via a test harness to prevent console spam.

## Existing Coverage

None. `BiometricBatcher` (a separate class downstream) has tests; this class has zero direct test coverage.

## Test Cases

### Constructor & Lifecycle

- **should subscribe to moduleStateEvents on construction**
  - Verify: lifecycle stream subscription is active and listening
  - Setup: construct client, emit a `ModuleSessionStarted` event, verify `_currentSessionId` is set

- **should subscribe to connectionState on construction**
  - Verify: connection stream subscription is active and listening
  - Setup: construct client, emit `GrpcConnectionState.connected`, verify `_ensureSinkOpen` was attempted

- **should cancel both subscriptions on dispose()**
  - Verify: after `dispose()`, emitting to both streams has no effect
  - Setup: construct, dispose, emit events, verify no state change

### Session Lifecycle & Gates

- **should set `_currentSessionId` and `_sessionConfirmed` on `ModuleSessionStarted`**
  - Verify: after emitting `ModuleSessionStarted(moduleSessionId: 'session-123')`, `_currentSessionId == 'session-123'` and `_sessionConfirmed == true`
  - Setup: emit lifecycle event and inspect via `sendBatch` being allowed (no-op guard skip)

- **should set `_currentSessionId` and `_sessionConfirmed` on `ModuleSessionResumed`**
  - Verify: after a reconnect cleared the session, emitting `ModuleSessionResumed(moduleSessionId: 'session-456')` re-confirms it
  - Setup: start session → disconnect (sets `_sessionConfirmed = false`) → emit `ModuleSessionResumed` → verify `_sessionConfirmed == true`

- **should clear `_currentSessionId` and `_sessionConfirmed` on `ModuleSessionEnded`**
  - Verify: after emitting `ModuleSessionEnded()`, `_currentSessionId == null` and `_sessionConfirmed == false`
  - Setup: emit lifecycle event and verify `sendBatch` becomes a no-op

- **should clear `_currentSessionId` and `_sessionConfirmed` on `ModuleSessionAbandoned`**
  - Verify: same as `ModuleSessionEnded`
  - Setup: emit `ModuleSessionAbandoned()` and verify gate closes

- **should clear replay ring on `ModuleSessionEnded` and `ModuleSessionAbandoned`**
  - Verify: after buffering samples to replay ring, emitting session-end clears it
  - Setup: send samples while unready (buffered to ring) → end session → verify ring is empty

- **should not gate on pause (`ModuleSessionPaused`/`ModuleSessionUnpaused`)**
  - Verify: sending samples through pause succeeds (no-op is skipped)
  - Setup: start session → emit `ModuleSessionPaused` → call `sendBatch(samples)` → verify samples flow (either enqueued to ring or sent if ready)

- **should reset `_lastOpenAttempt` on `ModuleSessionStarted`/`ModuleSessionResumed`**
  - Verify: after a failed open attempt, a session start resets the cooldown so the next `sendBatch` can open immediately
  - Setup: start session → trigger failed open (mock gRPC throw) → immediately emit `ModuleSessionStarted` → verify cooldown is reset

### Send Gate (`sendBatch`)

- **should be a no-op when `_currentSessionId == null`**
  - Verify: `sendBatch([sample1, sample2])` does not enqueue to ring or attempt to open sink
  - Setup: construct client without starting session, call `sendBatch`

- **should be a no-op when `!_sessionConfirmed` (unconfirmed session)**
  - Verify: after a reconnect, `_currentSessionId` is retained but `_sessionConfirmed = false`; `sendBatch` is silent no-op
  - Setup: start session → disconnect → call `sendBatch` → verify nothing happens

- **should be a no-op with empty sample list**
  - Verify: `sendBatch([])` returns immediately without side effects
  - Setup: start session, call `sendBatch([])`

- **should call `_ensureSinkOpen()` when session is live and confirmed**
  - Verify: mock `_ensureSinkOpen` call or inspect sink state after `sendBatch`
  - Setup: start session → call `sendBatch([sample])` → verify sink operation follows

### Readiness Gate (`_isReady`)

- **should reset `_isReady` to false on every `_ensureSinkOpen()`**
  - Verify: after a ready state, opening a new sink sets `_isReady = false` and re-gates outbound samples
  - Setup: open sink → receive `ready` event → close sink → open sink again → verify gate re-arms

- **should buffer samples to replay ring when `_sink != null && !_isReady`**
  - Verify: calling `sendBatch` while sink is open but not ready enqueues to ring instead of `sink.add`
  - Setup: mock gRPC stub to never emit `ready`; start session → call `sendBatch([s1, s2, s3])` → verify samples are in replay ring, not sent

- **should send samples to sink when `_isReady == true`**
  - Verify: after receiving `ready`, subsequent `sendBatch` calls send to sink directly
  - Setup: open sink → mock server emit `ready` → call `sendBatch([sample])` → verify `sink.add(batch)` was called

- **should drain replay ring on server `ready` event**
  - Verify: after buffering 5 samples while not ready, receiving `ready` drains all 5 to the sink
  - Setup: buffer samples to ring → mock server emit `ready` → verify drained samples sent in order

- **should clear replay ring after drain (no double-send)**
  - Verify: draining the ring on `ready` clears it; further samples after drain go directly to sink
  - Setup: buffer samples, emit `ready`, drain occurs, emit one more sample, verify only the new sample is in the final batch

### Readiness Timeout (5-second fallback)

- **should start a 5-second timer on `_ensureSinkOpen()`**
  - Verify: timer is created with `Duration(seconds: 5)`
  - Setup: use `fake_async` to spy on Timer creation, or inspect `_readyTimer` state

- **should fire fallback timer and force drain if no `ready` received within 5 seconds**
  - Verify: after 5 seconds with no server `ready`, `_isReady` is forced to true and replay ring drains
  - Setup: use `fake_async`, open sink, advance 5 seconds, buffer samples, verify drain occurs

- **should log warning on fallback timer fire**
  - Verify: "readiness timeout — draining without server ready" is logged
  - Setup: use `fake_async`, trigger fallback, spy on `logPrint`

- **should cancel timer on server `ready` event (no double drain)**
  - Verify: receiving `ready` before 5 seconds cancels the timer; timer does not fire afterward
  - Setup: use `fake_async`, open sink, emit `ready` at 2 seconds, advance to 6 seconds, verify timer did not fire a second time

- **should cancel timer on `_teardownSink()`**
  - Verify: closing the sink also cancels any pending readiness timer
  - Setup: open sink, manually call `_teardownSink()`, verify timer is null and cancelled

- **should cancel timer on dispose()**
  - Verify: after dispose, timer is null
  - Setup: construct, open sink, dispose, verify timer state

### Replay Ring (bounded drop-oldest buffer)

- **should enqueue samples to ring when `_sink == null` (pre-open)**
  - Verify: calling `_encodeAndAdd(samples)` with no sink routes to replay
  - Setup: call `sendBatch([sample])` before sink opens, verify it's enqueued to ring

- **should maintain FIFO order in ring**
  - Verify: enqueuing 5 samples in order yields the same order in the drained batch
  - Setup: manually enqueue via `_encodeAndAdd`, inspect ring after drain

- **should cap ring at 75 samples (drop oldest when full)**
  - Verify: enqueuing 76 samples results in the first sample being dropped, last 75 retained
  - Setup: manually enqueue 76 samples, verify ring.length == 75 and ring.first == sample 2

- **should clear ring on session end/abandon**
  - Verify: after buffering samples, ending the session clears the ring
  - Setup: start session, buffer samples, emit `ModuleSessionEnded`, verify ring is empty

- **should clear ring after drain on `ready`**
  - Verify: draining the ring sets it to empty state
  - Setup: buffer samples, emit `ready`, verify ring.isEmpty

### Reopen Cooldown (2 seconds)

- **should allow immediate open on first `_ensureSinkOpen()` call**
  - Verify: `_ensureSinkOpen()` opens sink without cooldown delay on first call
  - Setup: construct, call `sendBatch([sample])`, verify sink opens immediately

- **should record `_lastOpenAttempt` timestamp on every open**
  - Verify: after opening, `_lastOpenAttempt` is set to current time
  - Setup: use `fake_async`, open sink, inspect timestamp

- **should reject open attempt within 2 seconds of last attempt**
  - Verify: calling `sendBatch` twice in quick succession (< 2s) opens sink only once
  - Setup: use `fake_async`, call `sendBatch([s1])`, advance 0.5 seconds, call `sendBatch([s2])`, verify sink was not re-opened

- **should allow open attempt after 2 seconds have elapsed**
  - Verify: after 2 seconds, the next `sendBatch` opens a new sink
  - Setup: use `fake_async`, open sink, teardown after 2+ seconds, call `sendBatch`, verify new sink opens

- **should reset cooldown on session start/resume**
  - Verify: after a failed open, emitting `ModuleSessionStarted` resets `_lastOpenAttempt = null` so next `sendBatch` can open immediately
  - Setup: attempted open → session start → immediately call `sendBatch` → verify sink opens without delay

### Connection State Transitions

- **should call `_ensureSinkOpen()` on `GrpcConnectionState.connected`**
  - Verify: emitting `connected` triggers sink open attempt
  - Setup: emit `connected`, verify sink state or mock check

- **should call `_teardownSink()` on `GrpcConnectionState.disconnected`**
  - Verify: emitting `disconnected` closes the sink and cancels timers
  - Setup: emit `connected`, verify sink exists, emit `disconnected`, verify sink is null

- **should set `_sessionConfirmed = false` on disconnect (even with active `_currentSessionId`)**
  - Verify: after reconnect, the retained session id is unconfirmed until re-confirmed
  - Setup: start session → emit `disconnected` → verify `_sessionConfirmed == false` while `_currentSessionId` still has value

- **should ignore `GrpcConnectionState.connecting`**
  - Verify: emitting `connecting` has no effect
  - Setup: emit `connecting`, verify sink state unchanged

### Stream Error & Done Handling

- **should tear down sink on stream error**
  - Verify: server-side error (mock `_responseSub.listen` error path) closes sink
  - Setup: open sink, mock `response.listen(onError: ...)` callback, trigger error, verify `_teardownSink` was called

- **should tear down sink on stream done**
  - Verify: server closing the stream (mock `_responseSub.listen` done path) closes sink
  - Setup: open sink, mock `response.listen(onDone: ...)` callback, trigger done, verify `_teardownSink` was called

- **should log stream error**
  - Verify: error callback logs the exception
  - Setup: trigger error via mock, spy on `logPrint` for "[BiometricStreamClient] stream error: ..."

- **should log stream done**
  - Verify: done callback logs a message
  - Setup: trigger done via mock, spy on `logPrint` for "[BiometricStreamClient] stream done"

### gRPC Open Failure

- **should handle gRPC stub exception on `streamData` call**
  - Verify: if `_grpcStub.streamData(stream)` throws, the exception is caught, logged, and sink is torn down
  - Setup: mock stub to throw on `streamData` call, call `sendBatch`, verify no crash

- **should log open failure**
  - Verify: exception is logged with "[BiometricStreamClient] stream open failed: ..."
  - Setup: trigger exception, spy on `logPrint`

### Send Encoding & Proto Conversion

- **should encode `BioSample` to proto `BioSample` with current session id**
  - Verify: after calling `sendBatch([sample])`, the proto message includes the correct `sessionId`
  - Setup: start session with id 'session-xyz', call `sendBatch([sample])`, mock sink and inspect batch

- **should map `BioSample.timestampMs` to proto `Int64`**
  - Verify: proto batch contains correct timestamp
  - Setup: create sample with `timestampMs: 1234567890`, inspect proto message

- **should convert `BioSample.data` map to proto `Struct`**
  - Verify: nested map and primitive types are correctly converted to protobuf `Struct` and `Value`
  - Setup: create sample with complex data map (nested, mixed types), inspect `Struct` conversion

- **should handle null values in data map**
  - Verify: `null` is converted to `NullValue.NULL_VALUE`
  - Setup: create sample with `data: {'key': null}`, inspect proto

- **should handle string, int, double, bool values**
  - Verify: each primitive type is correctly mapped to proto `Value` union
  - Setup: create sample with all types, verify each `Value` field is correct

- **should handle nested maps (recursive Struct)**
  - Verify: `data: {'nested': {'key': 'value'}}` yields correct nested `Struct`
  - Setup: create sample, inspect proto structure depth

- **should handle list values**
  - Verify: `data: {'list': [1, 2, 3]}` yields `ListValue` with correct elements
  - Setup: create sample with list, inspect proto

- **should throw on unsupported data type**
  - Verify: if `data` contains an unsupported type (e.g., custom object), `_valueFrom` throws `ArgumentError`
  - Setup: attempt to encode sample with unsupported type, catch exception

### Send Sink Failures

- **should enqueue samples to replay ring on `sink.add` failure**
  - Verify: if sending to sink throws, samples are buffered to replay ring
  - Setup: mock sink.add to throw, call `sendBatch`, verify samples in ring

- **should tear down sink on send failure**
  - Verify: after send failure, sink is closed and set to null
  - Setup: trigger send failure, verify sink state

- **should log send failure**
  - Verify: "[BiometricStreamClient] stream send failed, enqueuing replay: ..." is logged
  - Setup: trigger send failure, spy on `logPrint`

### Server Response Handling

- **should handle `BioStreamResponse.ack` (no-op)**
  - Verify: receiving `ack` event causes no state change
  - Setup: mock server emit ack, verify no side effects

- **should handle `BioStreamResponse.error`**
  - Verify: error event is logged
  - Setup: mock server emit error with code/message, spy on `logPrint` for error details

- **should handle `BioStreamResponse.notSet` (no-op)**
  - Verify: receiving unset event causes no state change
  - Setup: mock server emit notSet, verify no side effects

### Dispose Lifecycle

- **should cancel readiness timer on dispose**
  - Verify: timer is null after dispose
  - Setup: construct, open sink, dispose, verify `_readyTimer == null`

- **should cancel connection subscription on dispose**
  - Verify: after dispose, emitting connection events has no effect
  - Setup: dispose, emit `connected`, verify no sink opens

- **should cancel lifecycle subscription on dispose**
  - Verify: after dispose, emitting session events has no effect
  - Setup: dispose, emit `ModuleSessionEnded` while `_currentSessionId` has value, verify no state change

- **should cancel response subscription on dispose**
  - Verify: `_responseSub?.cancel()` is awaited
  - Setup: open sink, dispose, verify subscription cancelled

- **should close sink on dispose**
  - Verify: `_sink?.close()` is called and sink is set to null
  - Setup: open sink, dispose, verify sink is null and closed

- **should clear replay ring on dispose**
  - Verify: ring is empty after dispose
  - Setup: buffer samples, dispose, verify ring is empty

- **should be a Future (awaitable)**
  - Verify: `dispose()` returns `Future<void>`, can be awaited
  - Setup: call `await client.dispose()`, verify completion

### Integration: Multiple Cycles (cold start, ready, send, disconnect, reconnect)

- **should handle full cold-start cycle: open → ready → send → drain**
  - Verify: from construction through multiple sends, samples flow correctly through buffering and drain
  - Setup: construct, start session, call `sendBatch([s1, s2])` (buffered), mock server emit `ready` (drain), call `sendBatch([s3])` (direct send), verify all 3 samples sent in order

- **should handle reconnect cycle: disconnect → reconnect → drain queued samples**
  - Verify: after disconnect-reconnect, queued samples from the previous session are cleared (not re-sent)
  - Setup: start session → buffer samples → emit `disconnected` → verify ring cleared

- **should handle mid-session reconnect with unconfirmed retention**
  - Verify: after `disconnected`, `_currentSessionId` is retained but `_sessionConfirmed = false`; sends are dropped until `ModuleSessionResumed` re-confirms
  - Setup: start session → buffer samples → emit `disconnected` → call `sendBatch([sample])` (silent no-op) → emit `ModuleSessionResumed` → call `sendBatch([sample])` (allowed) → verify first was dropped, second flowed

- **should handle pause without suppressing sends**
  - Verify: emitting `ModuleSessionPaused` does not prevent `sendBatch` from flowing
  - Setup: start session → emit `ModuleSessionPaused` → call `sendBatch([sample])` → verify sample flows

## Gotchas

- **gRPC stub mocking:** The real `ModuleBiometricStreamServiceClient.streamData` returns a stream immediately; the mock must also return a stream (not a Future). Capture the input stream controller for injecting server responses.
- **Lifecycle event sealed family:** `ModuleStateEvent` is a sealed class with 6 subtypes. The exhaustive switch in `_onLifecycleEvent` must be kept in sync; adding a new event type will cause compile error (good).
- **Connection state enum:** Only 3 states (connecting, connected, disconnected); the switch in the constructor subscription must be exhaustive. The `connecting` state is intentionally a no-op.
- **Timer-based tests:** Use `fake_async` package to control time. Wrap tests in `fakeAsync((_) { … })` and call `tick(Duration)` to advance. The 5-second fallback timer is critical for testing readiness timeout.
- **Ring lifecycle:** The ring is cleared on session end and after drain on `ready`. Tests must verify ring is empty at the right points, or unintended buffering occurs in subsequent cycles.
- **Cooldown window:** The 2-second reopen cooldown uses wall-clock `DateTime.now()`. Use `fake_async` or mock `DateTime.now()` (if refactored) to test precisely.
- **Readiness race:** If the server emits `ready` and the fallback timer fires in the same microsecond, both paths execute (but the second checks `!_isReady`, so double-drain is avoided). Tests are unlikely to trigger this, but be aware.
- **No backpressure:** BiometricStreamClient buffers samples into the ring with no limit besides the 75-sample cap (drop-oldest). If the sink is continuously unavailable, the ring will fill and drop old samples. Tests need not verify backpressure—that is by design.
- **Session id nullable:** `_currentSessionId` is `String?`; some branches check for null. `ModuleSessionStarted` and `ModuleSessionResumed` pass `moduleSessionId` which is also nullable (unusual, but matches the proto definition). Tests should use non-null session ids to avoid null-pointer edge cases unless specifically testing null handling.
- **Logging:** All logging is via `logPrint` (from `package:mind_logger`). Mock or suppress in test harness to avoid console spam. The project CLAUDE.md requires routing through `logPrint`, so do not expect raw `print` or `debugPrint` in this class.


## Refactor Required

**What to refactor:** Add two constructor parameters to `BiometricStreamClient`:
- `DateTime Function() clock` (default `DateTime.now`) — replaces the two `DateTime.now()` calls in `_ensureSinkOpen` for the 2 s cooldown check.
- `Duration readyTimeout` (default `const Duration(seconds: 5)`) — replaces the hardcoded `const Duration(seconds: 5)` in the fallback-timer construction.

**Current API** (refactor already done; see `BiometricStreamClient.dart` line 61–66):
```dart
BiometricStreamClient({
  required $bio.ModuleBiometricStreamServiceClient grpcStub,
  required Stream<ModuleStateEvent> moduleStateEvents,
  required Stream<GrpcConnectionState> connectionState,
  DateTime Function() clock = DateTime.now,
  Duration readyTimeout = const Duration(seconds: 5),
})
```

**What the test implementer gets:** Inject a fake clock via `clock: () => fakeTime` to advance time past the 2 s cooldown without waiting; pass `readyTimeout: Duration(milliseconds: 10)` for sub-10 ms fallback-timer tests. Defaults: `clock = DateTime.now`, `readyTimeout = 5 seconds`.
