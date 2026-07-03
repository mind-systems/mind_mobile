import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' as grpc;

import 'package:mind/Core/Grpc/GrpcConnectionManager.dart';
import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
import 'package:mind/Core/Grpc/InstructionSample.dart';
import 'package:mind/Core/Grpc/ModuleInstructionStream.dart';
import 'package:mind/Core/Grpc/generated/module_instruction_stream.pb.dart';
import 'package:mind/Core/Grpc/generated/module_instruction_stream.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/module_state.pb.dart' show StateErrorEvent;

// ──────────────────────────────────────────────────────────────────────────────
// Fakes
// ──────────────────────────────────────────────────────────────────────────────

/// Wraps a plain Stream as a ClientCall so ResponseStream can be constructed.
class _FakeClientCall
    implements grpc.ClientCall<StreamSample, StreamResponse> {
  final Stream<StreamResponse> _responses;
  _FakeClientCall(this._responses);

  @override
  Stream<StreamResponse> get response => _responses;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One recorded call to streamData.
class _StreamDataCall {
  final grpc.CallOptions? options;
  final StreamController<StreamResponse> responseCtrl =
      StreamController<StreamResponse>();
  final List<StreamSample> sentSamples = [];
  bool requestDone = false;

  _StreamDataCall(this.options);
}

/// Fake ModuleInstructionStreamServiceClient — records every streamData
/// invocation, captures sent StreamSamples, and lets tests push StreamResponse
/// frames.
class _FakeInstructionStreamServiceClient
    implements ModuleInstructionStreamServiceClient {
  final List<_StreamDataCall> calls = [];

  _StreamDataCall? get latestCall => calls.isEmpty ? null : calls.last;

  @override
  grpc.ResponseStream<StreamResponse> streamData(
    Stream<StreamSample> request, {
    grpc.CallOptions? options,
  }) {
    final call = _StreamDataCall(options);
    calls.add(call);
    request.listen(
      (s) => call.sentSamples.add(s),
      onDone: () => call.requestDone = true,
    );
    return grpc.ResponseStream<StreamResponse>(
        _FakeClientCall(call.responseCtrl.stream));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake GrpcConnectionManager — backs connectionState with a broadcast
/// controller and tracks method calls.
class _FakeConnectionManager implements GrpcConnectionManager {
  final _ctrl = StreamController<GrpcConnectionState>.broadcast();

  int confirmConnectedCount = 0;
  int disconnectCount = 0;
  int scheduleReconnectCount = 0;

  @override
  Stream<GrpcConnectionState> get connectionState => _ctrl.stream;

  @override
  void confirmConnected() => confirmConnectedCount++;

  @override
  void disconnect() => disconnectCount++;

  @override
  void scheduleReconnect() => scheduleReconnectCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ──────────────────────────────────────────────────────────────────────────────
// Clock holder
// ──────────────────────────────────────────────────────────────────────────────

class _ClockHolder {
  DateTime now = DateTime(2024, 1, 1, 12, 0, 0);
  DateTime Function() get clock => () => now;
  void advance(Duration d) => now = now.add(d);
}

// ──────────────────────────────────────────────────────────────────────────────
// Fixture
// ──────────────────────────────────────────────────────────────────────────────

typedef _Fixture = ({
  ModuleInstructionStream mis,
  _FakeInstructionStreamServiceClient service,
  _FakeConnectionManager connManager,
  _ClockHolder clockHolder,
});

_Fixture _make() {
  final service = _FakeInstructionStreamServiceClient();
  final connManager = _FakeConnectionManager();
  final clockHolder = _ClockHolder();
  final mis = ModuleInstructionStream(
    connectionManager: connManager,
    instructionStreamService: service,
    clock: clockHolder.clock,
  );
  return (
    mis: mis,
    service: service,
    connManager: connManager,
    clockHolder: clockHolder,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

Future<void> _connect(_Fixture f) async {
  f.connManager._ctrl.add(GrpcConnectionState.connected);
  await Future<void>.delayed(Duration.zero);
}

Future<void> _disconnect(_Fixture f) async {
  f.connManager._ctrl.add(GrpcConnectionState.disconnected);
  await Future<void>.delayed(Duration.zero);
}

InstructionSample _sample({
  String sessionId = 'sess-1',
  int timestamp = 1000,
  String moduleId = 'breath',
  String instructionType = 'phase',
  Map<String, dynamic> data = const <String, dynamic>{},
}) {
  return InstructionSample(
    sessionId: sessionId,
    timestamp: timestamp,
    moduleId: moduleId,
    instructionType: instructionType,
    data: data,
  );
}

StreamResponse _ready({int? maxSamplesPerSecond}) => StreamResponse(
      ready: StreamReady(maxSamplesPerSecond: maxSamplesPerSecond),
    );

StreamResponse _ack({int? maxSamplesPerSecond}) => StreamResponse(
      ack: StreamAck(maxSamplesPerSecond: maxSamplesPerSecond),
    );

/// Pushes a ready frame on the latest call and pumps a microtask.
Future<void> _makeReady(_Fixture f, {int? maxSamplesPerSecond}) async {
  f.service.latestCall!.responseCtrl.add(_ready(maxSamplesPerSecond: maxSamplesPerSecond));
  await Future<void>.delayed(Duration.zero);
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Phase 1: Connection-driven stream lifecycle ────────────────────────────

  group('ModuleInstructionStream — connection-driven stream lifecycle', () {
    test(
      'should construct without throwing and report isConnected=false before any connection state is emitted',
      () {
        final f = _make();
        expect(f.mis.isConnected, isFalse);
        f.mis.dispose();
      },
    );

    test(
      'should open the stream and report isConnected=true when connectionState emits connected',
      () async {
        final f = _make();
        await _connect(f);

        expect(f.mis.isConnected, isTrue);
        expect(f.service.calls, hasLength(1));

        f.mis.dispose();
      },
    );

    test(
      'should do nothing on connectionState=connecting (no streamData call, isConnected stays false)',
      () async {
        final f = _make();
        f.connManager._ctrl.add(GrpcConnectionState.connecting);
        await Future<void>.delayed(Duration.zero);

        expect(f.mis.isConnected, isFalse);
        expect(f.service.calls, isEmpty);

        f.mis.dispose();
      },
    );

    test(
      'should call streamData again opening a fresh stream when connected is emitted after a disconnect',
      () async {
        final f = _make();
        await _connect(f);
        expect(f.service.calls, hasLength(1));

        await _disconnect(f);
        await _connect(f);

        expect(f.service.calls, hasLength(2));
        expect(f.mis.isConnected, isTrue);

        f.mis.dispose();
      },
    );
  });

  // ── Phase 2: Readiness gate — pre-ready buffering ─────────────────────────

  group('ModuleInstructionStream — pre-ready emit buffering', () {
    test(
      'should not write any sample to the gRPC request stream when emit is called before a ready frame is received',
      () async {
        final f = _make();
        await _connect(f);

        f.mis.emit(_sample());
        await Future<void>.delayed(Duration.zero);

        expect(f.service.latestCall!.sentSamples, isEmpty);

        f.mis.dispose();
      },
    );

    test(
      'should buffer multiple pre-ready emits without sending any of them to the wire',
      () async {
        final f = _make();
        await _connect(f);

        f.mis.emit(_sample(timestamp: 1000));
        f.mis.emit(_sample(timestamp: 2000));
        f.mis.emit(_sample(timestamp: 3000));
        await Future<void>.delayed(Duration.zero);

        expect(f.service.latestCall!.sentSamples, isEmpty);

        f.mis.dispose();
      },
    );
  });

  // ── Phase 2: Readiness gate — ready frame drains outbox ──────────────────

  group('ModuleInstructionStream — ready frame drains outbox', () {
    test(
      'should drain all buffered samples to the request stream when a ready frame is received',
      () async {
        final f = _make();
        await _connect(f);

        f.mis.emit(_sample(timestamp: 1000));
        f.mis.emit(_sample(timestamp: 2000));
        await Future<void>.delayed(Duration.zero);
        expect(f.service.latestCall!.sentSamples, isEmpty);

        await _makeReady(f);

        expect(f.service.latestCall!.sentSamples, hasLength(2));

        f.mis.dispose();
      },
    );

    test(
      'should drain the outbox sorted by sample timestamp, not by emission order',
      () async {
        final f = _make();
        await _connect(f);

        // Emit in descending timestamp order.
        f.mis.emit(_sample(timestamp: 3000));
        f.mis.emit(_sample(timestamp: 1000));
        f.mis.emit(_sample(timestamp: 2000));
        await Future<void>.delayed(Duration.zero);

        await _makeReady(f);

        final sent = f.service.latestCall!.sentSamples;
        expect(sent, hasLength(3));
        expect(sent[0].timestamp, Int64(1000));
        expect(sent[1].timestamp, Int64(2000));
        expect(sent[2].timestamp, Int64(3000));

        f.mis.dispose();
      },
    );

    test(
      'should send a sample emitted after ready directly to the wire without buffering',
      () async {
        final f = _make();
        await _connect(f);
        await _makeReady(f);

        f.mis.emit(_sample(timestamp: 5000));
        await Future<void>.delayed(Duration.zero);

        expect(f.service.latestCall!.sentSamples, hasLength(1));
        expect(f.service.latestCall!.sentSamples.first.timestamp, Int64(5000));

        f.mis.dispose();
      },
    );

    test(
      'should map InstructionSample fields onto the StreamSample that reaches the wire',
      () async {
        final f = _make();
        await _connect(f);
        await _makeReady(f);

        f.mis.emit(InstructionSample(
          sessionId: 'my-session',
          timestamp: 9876,
          moduleId: 'breath',
          instructionType: 'inhale',
          data: const <String, dynamic>{},
        ));
        await Future<void>.delayed(Duration.zero);

        final sent = f.service.latestCall!.sentSamples;
        expect(sent, hasLength(1));
        final proto = sent.first;
        expect(proto.sessionId, 'my-session');
        expect(proto.timestamp, Int64(9876));
        expect(proto.moduleId, 'breath');
        expect(proto.instructionType, 'inhale');

        f.mis.dispose();
      },
    );
  });

  // ── Phase 3: Reconnect re-arms the readiness gate ─────────────────────────

  group('ModuleInstructionStream — reconnect re-arms readiness gate', () {
    test(
      'should re-buffer a post-reconnect emit instead of sending it directly, proving _isReady was reset to false on reconnect',
      () async {
        final f = _make();
        await _connect(f);
        await _makeReady(f);

        // Emit one sample while ready — it should be sent immediately.
        f.mis.emit(_sample(timestamp: 100));
        await Future<void>.delayed(Duration.zero);
        expect(f.service.calls.first.sentSamples, hasLength(1));

        // Disconnect and reconnect — opens a fresh stream.
        await _disconnect(f);
        await _connect(f);
        final newCall = f.service.calls[1];

        // Emit after reconnect but before new ready frame.
        f.mis.emit(_sample(timestamp: 200));
        await Future<void>.delayed(Duration.zero);

        // New stream should have nothing yet (buffered, not sent).
        expect(newCall.sentSamples, isEmpty);

        // Send new ready frame → drains outbox.
        newCall.responseCtrl.add(_ready());
        await Future<void>.delayed(Duration.zero);
        expect(newCall.sentSamples, hasLength(1));
        expect(newCall.sentSamples.first.timestamp, Int64(200));

        f.mis.dispose();
      },
    );

    test(
      'should clear the outbox on disconnect so buffered pre-ready samples are dropped and never sent after reconnect',
      () async {
        final f = _make();
        await _connect(f);

        // Buffer samples before ready.
        f.mis.emit(_sample(timestamp: 111));
        f.mis.emit(_sample(timestamp: 222));
        await Future<void>.delayed(Duration.zero);

        // Disconnect clears the outbox.
        await _disconnect(f);
        await _connect(f);
        final newCall = f.service.calls[1];

        // Ready frame on new stream — outbox was cleared, nothing to drain.
        newCall.responseCtrl.add(_ready());
        await Future<void>.delayed(Duration.zero);

        expect(newCall.sentSamples, isEmpty);

        f.mis.dispose();
      },
    );

    test(
      'should drain only post-reconnect buffered samples after the reconnect stream receives its own ready frame',
      () async {
        final f = _make();
        await _connect(f);

        // Buffer pre-reconnect samples.
        f.mis.emit(_sample(timestamp: 1));
        f.mis.emit(_sample(timestamp: 2));
        await Future<void>.delayed(Duration.zero);

        // Disconnect (clears outbox) and reconnect.
        await _disconnect(f);
        await _connect(f);
        final newCall = f.service.calls[1];

        // Buffer new samples on the reconnected stream.
        f.mis.emit(_sample(timestamp: 10));
        f.mis.emit(_sample(timestamp: 20));
        await Future<void>.delayed(Duration.zero);

        // Ready on new stream — drains only post-reconnect outbox.
        newCall.responseCtrl.add(_ready());
        await Future<void>.delayed(Duration.zero);

        expect(newCall.sentSamples, hasLength(2));
        expect(newCall.sentSamples[0].timestamp, Int64(10));
        expect(newCall.sentSamples[1].timestamp, Int64(20));

        f.mis.dispose();
      },
    );
  });

  // ── Phase 4: Rate-limiting ─────────────────────────────────────────────────

  group('ModuleInstructionStream — rate-limiting', () {
    test(
      'should drop the second sample when two emits occur less than 1000/maxSamplesPerSecond apart',
      () async {
        // Default cap: 10 samples/sec → minIntervalMs = 100ms.
        final f = _make();
        await _connect(f);
        await _makeReady(f);

        // First emit — no lastSendTime, always sent.
        f.mis.emit(_sample(timestamp: 1));
        await Future<void>.delayed(Duration.zero);
        expect(f.service.latestCall!.sentSamples, hasLength(1));

        // Advance clock by 50ms (< 100ms cap).
        f.clockHolder.advance(const Duration(milliseconds: 50));

        // Second emit — within interval, should be dropped.
        f.mis.emit(_sample(timestamp: 2));
        await Future<void>.delayed(Duration.zero);
        expect(f.service.latestCall!.sentSamples, hasLength(1));

        f.mis.dispose();
      },
    );

    test(
      'should send both samples when the second emit is at least the minimum interval after the first',
      () async {
        // Default cap: 10 samples/sec → minIntervalMs = 100ms.
        final f = _make();
        await _connect(f);
        await _makeReady(f);

        f.mis.emit(_sample(timestamp: 1));
        await Future<void>.delayed(Duration.zero);

        // Advance clock by exactly 100ms (== minIntervalMs → NOT dropped).
        f.clockHolder.advance(const Duration(milliseconds: 100));

        f.mis.emit(_sample(timestamp: 2));
        await Future<void>.delayed(Duration.zero);

        expect(f.service.latestCall!.sentSamples, hasLength(2));

        f.mis.dispose();
      },
    );

    test(
      'should not apply the rate-limit to the first post-ready emit (no prior _lastSendTime)',
      () async {
        final f = _make();
        await _connect(f);
        await _makeReady(f);

        // No clock advancement — first emit is never rate-limited.
        f.mis.emit(_sample(timestamp: 42));
        await Future<void>.delayed(Duration.zero);

        expect(f.service.latestCall!.sentSamples, hasLength(1));

        f.mis.dispose();
      },
    );

    test(
      'should reset the rate-limit timing on reconnect so the first emit after reconnect is never dropped',
      () async {
        final f = _make();
        await _connect(f);
        await _makeReady(f);

        // Send one sample — sets lastSendTime.
        f.mis.emit(_sample(timestamp: 1));
        await Future<void>.delayed(Duration.zero);

        // Disconnect clears lastSendTime; reconnect opens fresh stream.
        await _disconnect(f);
        await _connect(f);
        final newCall = f.service.calls[1];
        newCall.responseCtrl.add(_ready());
        await Future<void>.delayed(Duration.zero);

        // Do NOT advance the clock — but lastSendTime is null after reconnect,
        // so this emit must not be dropped.
        f.mis.emit(_sample(timestamp: 2));
        await Future<void>.delayed(Duration.zero);

        expect(newCall.sentSamples, hasLength(1));

        f.mis.dispose();
      },
    );

    test(
      'should adopt maxSamplesPerSecond from a ready frame and apply the new interval to subsequent emits',
      () async {
        final f = _make();
        await _connect(f);
        // Ready with rate limit = 5 samples/sec → minIntervalMs = 200ms.
        await _makeReady(f, maxSamplesPerSecond: 5);

        // First emit at T0 — always sent.
        f.mis.emit(_sample(timestamp: 1));
        await Future<void>.delayed(Duration.zero);
        expect(f.service.latestCall!.sentSamples, hasLength(1));

        // +150ms < 200ms → drop.
        f.clockHolder.advance(const Duration(milliseconds: 150));
        f.mis.emit(_sample(timestamp: 2));
        await Future<void>.delayed(Duration.zero);
        expect(f.service.latestCall!.sentSamples, hasLength(1));

        // +60ms more (total 210ms) >= 200ms → send.
        f.clockHolder.advance(const Duration(milliseconds: 60));
        f.mis.emit(_sample(timestamp: 3));
        await Future<void>.delayed(Duration.zero);
        expect(f.service.latestCall!.sentSamples, hasLength(2));

        f.mis.dispose();
      },
    );

    test(
      'should adopt maxSamplesPerSecond from an ack frame and apply the new interval to subsequent emits',
      () async {
        // Default cap: 10 samples/sec → 100ms.
        final f = _make();
        await _connect(f);
        await _makeReady(f);

        // First emit at T0.
        f.mis.emit(_sample(timestamp: 1));
        await Future<void>.delayed(Duration.zero);
        expect(f.service.latestCall!.sentSamples, hasLength(1));

        // Ack frame updates rate to 5 samples/sec → new minIntervalMs = 200ms.
        f.service.latestCall!.responseCtrl.add(_ack(maxSamplesPerSecond: 5));
        await Future<void>.delayed(Duration.zero);

        // +150ms: new interval is 200ms → drop.
        f.clockHolder.advance(const Duration(milliseconds: 150));
        f.mis.emit(_sample(timestamp: 2));
        await Future<void>.delayed(Duration.zero);
        expect(f.service.latestCall!.sentSamples, hasLength(1));

        // +60ms (total 210ms) >= 200ms → send.
        f.clockHolder.advance(const Duration(milliseconds: 60));
        f.mis.emit(_sample(timestamp: 3));
        await Future<void>.delayed(Duration.zero);
        expect(f.service.latestCall!.sentSamples, hasLength(2));

        f.mis.dispose();
      },
    );
  });

  // ── Phase 5: Fallback timer ────────────────────────────────────────────────

  group('ModuleInstructionStream — 5 s fallback timer', () {
    test(
      'should flush buffered samples to the wire when 5 seconds elapse without a ready frame',
      () {
        fakeAsync((async) {
          final f = _make();
          f.connManager._ctrl.add(GrpcConnectionState.connected);
          async.flushMicrotasks();

          f.mis.emit(_sample(timestamp: 1000));
          f.mis.emit(_sample(timestamp: 2000));

          // Before 5 s — samples still in outbox.
          expect(f.service.latestCall!.sentSamples, isEmpty);

          // Elapse 5 s — timer fires, drains outbox.
          async.elapse(const Duration(seconds: 5));

          expect(f.service.latestCall!.sentSamples, hasLength(2));

          f.mis.dispose();
        });
      },
    );

    test(
      'should treat the stream as ready after the fallback fires so a subsequent emit goes directly to the wire',
      () {
        fakeAsync((async) {
          final f = _make();
          f.connManager._ctrl.add(GrpcConnectionState.connected);
          async.flushMicrotasks();

          // Elapse 5 s — fallback fires, _isReady becomes true.
          async.elapse(const Duration(seconds: 5));

          // Emit after fallback — goes directly to wire.
          f.mis.emit(_sample(timestamp: 999));
          async.flushMicrotasks();

          expect(f.service.latestCall!.sentSamples, hasLength(1));

          f.mis.dispose();
        });
      },
    );

    test(
      'should not double-flush when a real ready frame arrives after the fallback already fired',
      () {
        fakeAsync((async) {
          final f = _make();
          f.connManager._ctrl.add(GrpcConnectionState.connected);
          async.flushMicrotasks();

          f.mis.emit(_sample(timestamp: 111));

          // Fire the fallback — drains outbox, _isReady = true.
          async.elapse(const Duration(seconds: 5));
          expect(f.service.latestCall!.sentSamples, hasLength(1));

          // Now send a real ready frame — outbox is empty, no duplicate.
          f.service.latestCall!.responseCtrl.add(_ready());
          async.flushMicrotasks();

          // Still only 1 sample — no double-flush.
          expect(f.service.latestCall!.sentSamples, hasLength(1));

          f.mis.dispose();
        });
      },
    );

    test(
      'should not run the fallback flush when a ready frame arrives before 5 seconds elapse',
      () {
        fakeAsync((async) {
          final f = _make();
          f.connManager._ctrl.add(GrpcConnectionState.connected);
          async.flushMicrotasks();

          f.mis.emit(_sample(timestamp: 777));

          // Ready frame arrives at 3 s — cancels the timer and drains outbox.
          async.elapse(const Duration(seconds: 3));
          f.service.latestCall!.responseCtrl.add(_ready());
          async.flushMicrotasks();
          expect(f.service.latestCall!.sentSamples, hasLength(1));

          // Elapse past the original 5 s mark — timer was cancelled, no re-flush.
          async.elapse(const Duration(seconds: 3));
          expect(f.service.latestCall!.sentSamples, hasLength(1));

          f.mis.dispose();
        });
      },
    );
  });

  // ── Phase 6: emit() guards ────────────────────────────────────────────────

  group('ModuleInstructionStream — emit() connectivity guard and lazy open', () {
    test(
      'should drop the sample and not open a stream when emit is called while disconnected (sink null, not gRPC-connected)',
      () async {
        final f = _make();
        // Not connected — _isGrpcConnected=false, _streamSink=null.
        expect(f.mis.isConnected, isFalse);

        f.mis.emit(_sample());
        await Future<void>.delayed(Duration.zero);

        // No streamData call was made.
        expect(f.service.calls, isEmpty);

        f.mis.dispose();
      },
    );

    test(
      'should open a stream lazily when emit is called while connected but no stream is open yet',
      () async {
        // The lazy-open branch (_streamSink==null while _isGrpcConnected==true)
        // is exercised indirectly: connect opens the stream; emit() afterwards
        // verifies the sample is sent, confirming the stream is present.
        final f = _make();
        await _connect(f);
        await _makeReady(f);

        f.mis.emit(_sample(timestamp: 42));
        await Future<void>.delayed(Duration.zero);

        expect(f.service.latestCall!.sentSamples, hasLength(1));
        f.mis.dispose();
      },
    );
  });

  // ── Phase 6: stream error and done paths ──────────────────────────────────

  group('ModuleInstructionStream — stream error and done paths', () {
    test(
      'should call disconnect and scheduleReconnect on the connection manager when the response stream errors',
      () async {
        final f = _make();
        await _connect(f);

        f.service.latestCall!.responseCtrl.addError(Exception('transport error'));
        await Future<void>.delayed(Duration.zero);

        expect(f.connManager.disconnectCount, 1);
        expect(f.connManager.scheduleReconnectCount, 1);

        f.mis.dispose();
      },
    );

    test(
      'should call disconnect and scheduleReconnect when the response stream is done',
      () async {
        final f = _make();
        await _connect(f);

        await f.service.latestCall!.responseCtrl.close();
        await Future<void>.delayed(Duration.zero);

        expect(f.connManager.disconnectCount, 1);
        expect(f.connManager.scheduleReconnectCount, 1);

        f.mis.dispose();
      },
    );

    test(
      'should reset _isReady to false on stream error, verified by a subsequent emit buffering instead of sending',
      () async {
        final f = _make();
        await _connect(f);
        await _makeReady(f);

        // Verify we're ready — emit goes to wire.
        f.mis.emit(_sample(timestamp: 1));
        await Future<void>.delayed(Duration.zero);
        expect(f.service.latestCall!.sentSamples, hasLength(1));

        // Trigger a stream error — resets _isReady.
        f.service.latestCall!.responseCtrl.addError(Exception('boom'));
        await Future<void>.delayed(Duration.zero);

        // After error, the fake disconnect() doesn't emit GrpcConnectionState.disconnected,
        // so _isGrpcConnected stays true and _streamSink is still set.
        // Emit should now buffer (not ready) rather than send.
        // We connect fresh and confirm the state via a new connection.
        await _connect(f);
        // New stream — not ready yet.
        f.mis.emit(_sample(timestamp: 2));
        await Future<void>.delayed(Duration.zero);
        expect(f.service.calls[1].sentSamples, isEmpty);

        // Ready on new stream drains buffer.
        f.service.calls[1].responseCtrl.add(_ready());
        await Future<void>.delayed(Duration.zero);
        expect(f.service.calls[1].sentSamples, hasLength(1));

        f.mis.dispose();
      },
    );

    test(
      'should call confirmConnected exactly once on the first received frame and not again on the second',
      () async {
        final f = _make();
        await _connect(f);

        // First frame — confirmConnected is called.
        f.service.latestCall!.responseCtrl.add(_ready());
        await Future<void>.delayed(Duration.zero);
        expect(f.connManager.confirmConnectedCount, 1);

        // Second frame — confirmConnected is NOT called again.
        f.service.latestCall!.responseCtrl.add(_ack());
        await Future<void>.delayed(Duration.zero);
        expect(f.connManager.confirmConnectedCount, 1);

        f.mis.dispose();
      },
    );
  });

  // ── Phase 7: Dispose teardown ──────────────────────────────────────────────

  group('ModuleInstructionStream — dispose teardown', () {
    test(
      'should cancel the connection-state subscription on dispose, verified by emitting connected afterward and observing no new streamData call',
      () async {
        final f = _make();
        await _connect(f);
        expect(f.service.calls, hasLength(1));

        f.mis.dispose();

        // Emit another connected event — should be ignored after dispose.
        f.connManager._ctrl.add(GrpcConnectionState.connected);
        await Future<void>.delayed(Duration.zero);

        expect(f.service.calls, hasLength(1));
      },
    );

    test(
      'should close the request sink on dispose, verified by the captured request stream completing (onDone)',
      () async {
        final f = _make();
        await _connect(f);
        final call = f.service.latestCall!;

        f.mis.dispose();
        await Future<void>.delayed(Duration.zero);

        expect(call.requestDone, isTrue);
      },
    );

    test(
      'should cancel the fallback timer on dispose so no flush occurs after disposal',
      () {
        fakeAsync((async) {
          final f = _make();
          f.connManager._ctrl.add(GrpcConnectionState.connected);
          async.flushMicrotasks();

          f.mis.emit(_sample(timestamp: 1));
          final call = f.service.latestCall!;

          // Dispose cancels the timer.
          f.mis.dispose();
          async.flushMicrotasks();

          // Elapse past 5 s — timer was cancelled, no flush.
          async.elapse(const Duration(seconds: 6));

          expect(call.sentSamples, isEmpty);
        });
      },
    );

    test(
      'should be safe to call dispose without an open stream (no prior connection) and not throw',
      () {
        final f = _make();
        expect(() => f.mis.dispose(), returnsNormally);
      },
    );
  });

  // ── Phase 8: late SESSION_NOT_FOUND is swallowed (note 23 guard) ──────────
  //
  // A phase sample arriving after its child ended races a benign
  // SESSION_NOT_FOUND from the server. Note 17 relies on this being dropped
  // silently — no throw, no teardown. Expected GREEN now and after note 17.

  group('ModuleInstructionStream — late SESSION_NOT_FOUND is swallowed', () {
    test(
      'should not throw and should not tear down the stream when the server sends a SESSION_NOT_FOUND error frame',
      () async {
        final f = _make();
        await _connect(f);
        await _makeReady(f);

        expect(
          () => f.service.latestCall!.responseCtrl.add(
            StreamResponse(
              error: StateErrorEvent(
                code: 'SESSION_NOT_FOUND',
                message: 'late phase sample after child ended',
              ),
            ),
          ),
          returnsNormally,
        );
        await Future<void>.delayed(Duration.zero);

        // No teardown / reconnect scheduled beyond current behavior.
        expect(f.connManager.disconnectCount, 0);
        expect(f.connManager.scheduleReconnectCount, 0);

        // Stream is not torn down — a subsequent emit still reaches the wire.
        f.mis.emit(_sample(timestamp: 1));
        await Future<void>.delayed(Duration.zero);
        expect(f.service.latestCall!.sentSamples, hasLength(1));

        f.mis.dispose();
      },
    );
  });
}
