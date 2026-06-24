# Test Plan: ModuleInstructionStream readiness-gate and rate-limit tests

## Context
`lib/Core/Grpc/ModuleInstructionStream.dart` is the transport-layer adapter that streams module instruction samples to the server over bidirectional gRPC. It is currently untested at the unit level — existing coverage only fakes the domain-level `BreathModuleInstructionStream` interface. This plan covers the readiness gate (pre-ready FIFO outbox), outbox draining on `ready`, reconnect re-arming, rate-limit enforcement, the 5 s fallback timer, and `dispose()` teardown.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`/usr/local/bin/flutter test test/Core/Grpc/module_instruction_stream_test.dart`

## Target Spec File
`test/Core/Grpc/module_instruction_stream_test.dart`

## Prerequisite Status
- **Clock injection (ROADMAP Test Infra) — ALREADY DONE.** `ModuleInstructionStream` already exposes the `DateTime Function() clock = DateTime.now` constructor parameter (`_clock` field at line 18, used in `emit()` at lines 93 and 101). No source refactor is required; tests inject `clock:` directly.

## Test Harness Notes (for the implementer — not a task)
Build these fakes/helpers in the spec file (follow the patterns in `test/Core/Grpc/module_state_channel_test.dart`):
- **`_FakeConnectionManager implements GrpcConnectionManager`** — back `connectionState` with a `StreamController<GrpcConnectionState>.broadcast()`; expose `int confirmConnectedCount / disconnectCount / scheduleReconnectCount`; use `noSuchMethod` for the rest.
- **`_FakeInstructionStreamServiceClient implements ModuleInstructionStreamServiceClient`** — implement `streamData(Stream<StreamSample> request, {CallOptions? options})`: record each `streamData` invocation, subscribe to `request` and append every `StreamSample` to a captured `List<StreamSample> sentSamples`, and return a `grpc.ResponseStream<StreamResponse>` wrapping a per-call `StreamController<StreamResponse>` (use the `_FakeClientCall` wrapper pattern from `module_state_channel_test.dart`). Expose the latest call's response controller so tests can push `StreamResponse` frames.
- **Manual clock** — a mutable `DateTime` holder with a `() => now` closure passed as `clock:`, advanced by reassignment between `emit()` calls.
- **Helpers** — `_connect(f)` adds `GrpcConnectionState.connected` + awaits `Future<void>.delayed(Duration.zero)`; `_disconnect(f)`; a `_sample({sessionId, timestamp, ...})` factory returning an `InstructionSample`; a `_ready({maxSamplesPerSecond})` and `_ack({maxSamplesPerSecond})` `StreamResponse` factory.
- Samples written to the request stream arrive asynchronously — always `await Future<void>.delayed(Duration.zero)` before asserting on `sentSamples`.
- For the 5 s fallback timer (and any other real-`Timer` behavior), wrap the test body in `fakeAsync` from `package:fake_async` (already a dev dependency) and use `async.elapse(...)`. `fake_async` also controls `clock` if you prefer, but the rate-limit tests are simplest with the manual `DateTime` holder.
- Private fields (`_isReady`, `_outbox`, `_lastSendTime`) are not exposed — verify them indirectly through `sentSamples` content/order and the connection-manager spies.

## Tasks

### Phase 1: Connection-driven stream lifecycle

- [x] **Task 1: Construction and stream opening**
  Files: `test/Core/Grpc/module_instruction_stream_test.dart`
  Test cases:
  - `should construct without throwing and report isConnected=false before any connection state is emitted`
  - `should open the stream and report isConnected=true when connectionState emits connected`
  - `should do nothing on connectionState=connecting (no streamData call, isConnected stays false)`
  - `should call streamData again opening a fresh stream when connected is emitted after a disconnect`

### Phase 2: Readiness gate and FIFO outbox

- [x] **Task 2: Pre-ready emits buffer in the outbox instead of reaching the wire**
  Files: `test/Core/Grpc/module_instruction_stream_test.dart`
  Test cases:
  - `should not write any sample to the gRPC request stream when emit is called before a ready frame is received`
  - `should buffer multiple pre-ready emits without sending any of them to the wire`

- [x] **Task 3: ready frame drains the outbox in timestamp order and unblocks further emits**
  Files: `test/Core/Grpc/module_instruction_stream_test.dart`
  Test cases:
  - `should drain all buffered samples to the request stream when a ready frame is received`
  - `should drain the outbox sorted by sample timestamp, not by emission order` (emit samples with descending timestamps before ready; assert sentSamples are ascending — exercises the `_outbox.sort` at line 180)
  - `should send a sample emitted after ready directly to the wire without buffering`
  - `should map InstructionSample fields (sessionId, timestamp, moduleId, instructionType) onto the StreamSample that reaches the wire` (verifies the `_toProto` conversion on the emit path is exercised end-to-end)

### Phase 3: Reconnect re-arms the readiness gate

- [x] **Task 4: A second _openStream resets the ready flag, outbox, and send time**
  Files: `test/Core/Grpc/module_instruction_stream_test.dart`
  Test cases:
  - `should re-buffer a post-reconnect emit instead of sending it directly, proving _isReady was reset to false on reconnect` (connect → ready → emit (sent) → disconnect → reconnect → emit → assert the new sample is NOT on the new stream's sentSamples until a fresh ready arrives)
  - `should clear the outbox on disconnect so buffered pre-ready samples are dropped and never sent after reconnect`
  - `should drain only post-reconnect buffered samples after the reconnect stream receives its own ready frame`

### Phase 4: Rate-limiting (clock-driven)

- [x] **Task 5: Drop samples emitted faster than the cap; allow spaced samples**
  Files: `test/Core/Grpc/module_instruction_stream_test.dart`
  Test cases:
  - `should drop the second sample when two emits occur less than 1000/maxSamplesPerSecond apart` (default cap 10 → 100 ms interval; advance the injected clock by 50 ms between emits; assert only the first sample reaches the wire)
  - `should send both samples when the second emit is at least the minimum interval after the first` (advance the clock by 100 ms; assert both reach the wire)
  - `should not apply the rate-limit to the first post-ready emit (no prior _lastSendTime)`
  - `should reset the rate-limit timing on reconnect so the first emit after reconnect is never dropped` (emit, disconnect, reconnect+ready, emit with the clock unadvanced → still sent because `_lastSendTime` was nulled)
  - `should adopt maxSamplesPerSecond from a ready frame and apply the new interval to subsequent emits`
  - `should adopt maxSamplesPerSecond from an ack frame and apply the new interval to subsequent emits`

### Phase 5: Fallback timer (un-upgraded server)

- [x] **Task 6: 5 s fallback flushes the outbox without a server ready frame**
  Files: `test/Core/Grpc/module_instruction_stream_test.dart`
  Test cases:
  - `should flush buffered samples to the wire when 5 seconds elapse without a ready frame` (use `fakeAsync`; emit before ready, `async.elapse(Duration(seconds: 5))`, assert buffered samples reach the wire)
  - `should treat the stream as ready after the fallback fires so a subsequent emit goes directly to the wire`
  - `should not double-flush when a real ready frame arrives after the fallback already fired` (the `_onReadyTimeout` early-return on `_isReady` and `_readyTimer?.cancel()` in the ready branch)
  - `should not run the fallback flush when a ready frame arrives before 5 seconds elapse` (elapse <5 s after ready; assert no extra/duplicate sends and timer cancelled)
  - Optional: `should log a readiness-timeout warning when the fallback fires` — only if the implementer adds a log capture seam; otherwise assert the behavioral flush above and skip log-string assertions.

### Phase 6: emit() guards and error/done paths

- [x] **Task 7: emit() connectivity guard and lazy open**
  Files: `test/Core/Grpc/module_instruction_stream_test.dart`
  Test cases:
  - `should drop the sample and not open a stream when emit is called while disconnected (sink null, not gRPC-connected)`
  - `should open a stream lazily when emit is called while connected but no stream is open yet`

- [x] **Task 8: stream error and done trigger reconnect and reset readiness**
  Files: `test/Core/Grpc/module_instruction_stream_test.dart`
  Test cases:
  - `should call disconnect and scheduleReconnect on the connection manager when the response stream errors`
  - `should call disconnect and scheduleReconnect when the response stream is done`
  - `should reset _isReady to false on stream error, verified by a subsequent emit buffering instead of sending`
  - `should call confirmConnected exactly once on the first received frame and not again on the second`

### Phase 7: Dispose teardown

- [x] **Task 9: dispose() cancels subscriptions and closes the sink**
  Files: `test/Core/Grpc/module_instruction_stream_test.dart`
  Test cases:
  - `should cancel the connection-state subscription on dispose, verified by emitting connected afterward and observing no new streamData call`
  - `should close the request sink on dispose, verified by the captured request stream completing (onDone)`
  - `should cancel the fallback timer on dispose so no flush occurs after disposal` (use `fakeAsync`; emit pre-ready, dispose, `async.elapse(5 s)`, assert nothing was sent)
  - `should be safe to call dispose without an open stream (no prior connection) and not throw`
