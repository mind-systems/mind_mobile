import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart' show debugPrint, DebugPrintCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/service_api.dart' as $grpc;

import 'package:mind/Biometrics/BioSample.dart';
import 'package:mind/Biometrics/BiometricStreamClient.dart';
import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
import 'package:mind/Core/Grpc/ModuleStateEvent.dart';
import 'package:mind/Core/Grpc/generated/module_biometric_stream.pbgrpc.dart'
    as $bio;

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Per-call state: captures request batches and owns the server-side response
/// controller for one invocation of [streamData].
class _FakeConnection {
  final List<$bio.BioSampleBatch> batches = [];
  final StreamController<$bio.BioStreamResponse> _responseCtrl =
      StreamController<$bio.BioStreamResponse>.broadcast();

  _FakeConnection(Stream<$bio.BioSampleBatch> requestStream) {
    requestStream.listen((batch) => batches.add(batch));
  }

  $grpc.ResponseStream<$bio.BioStreamResponse> get responseStream =>
      _FakeResponseStream(_responseCtrl.stream);

  void injectReady() =>
      _responseCtrl.add($bio.BioStreamResponse(ready: $bio.BioStreamReady()));

  void injectAck() =>
      _responseCtrl.add($bio.BioStreamResponse(ack: $bio.BioStreamAck()));

  void injectError(Object error) => _responseCtrl.addError(error);

  void closeStream() => _responseCtrl.close();
}

class _FakeResponseStream
    implements $grpc.ResponseStream<$bio.BioStreamResponse> {
  final Stream<$bio.BioStreamResponse> _stream;

  _FakeResponseStream(this._stream);

  @override
  StreamSubscription<$bio.BioStreamResponse> listen(
    void Function($bio.BioStreamResponse event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _stream.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStub implements $bio.ModuleBiometricStreamServiceClient {
  final List<_FakeConnection> connections = [];

  _FakeConnection get latest => connections.last;
  int get callCount => connections.length;

  @override
  $grpc.ResponseStream<$bio.BioStreamResponse> streamData(
    Stream<$bio.BioSampleBatch> request, {
    $grpc.CallOptions? options,
  }) {
    final conn = _FakeConnection(request);
    connections.add(conn);
    return conn.responseStream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

BioSample _sample(int timestampMs) =>
    BioSample(timestampMs: timestampMs, sampleType: 'rr', data: const {});

/// Asserts that [check] is true after flushing microtasks.
void _flush(FakeAsync async, [void Function()? check]) {
  async.flushMicrotasks();
  check?.call();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Phase 1: Session-confirmation gate on sendBatch ───────────────────────

  group('BiometricStreamClient — session gate', () {
    test('should be a no-op when no session has started', () {
      fakeAsync((async) {
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
        );

        sut.sendBatch([_sample(1)]);
        async.flushMicrotasks();

        expect(stub.callCount, 0);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });

    test('should send after ModuleSessionStarted confirms the session', () {
      fakeAsync((async) {
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          readyTimeout: const Duration(hours: 1),
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();

        sut.sendBatch([_sample(1)]);
        async.flushMicrotasks();

        // stream opened, sample buffered (not ready yet)
        expect(stub.callCount, 1);
        expect(stub.latest.batches, isEmpty);

        stub.latest.injectReady();
        async.flushMicrotasks();

        expect(stub.latest.batches.length, 1);
        expect(stub.latest.batches.first.samples.length, 1);
        expect(stub.latest.batches.first.samples.first.sessionId, 's1');
        expect(stub.latest.batches.first.samples.first.timestamp.toInt(), 1);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });

    test('should be a no-op with an empty sample list when a session is confirmed',
        () {
      fakeAsync((async) {
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();

        sut.sendBatch([]);
        async.flushMicrotasks();

        expect(stub.callCount, 0);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });

    test(
        'should drop sendBatch after disconnect clears session confirmation', () {
      fakeAsync((async) {
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        connectionCtrl.add(GrpcConnectionState.disconnected);
        async.flushMicrotasks();

        sut.sendBatch([_sample(1)]);
        async.flushMicrotasks();

        expect(stub.callCount, 0);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });

    test(
        'should re-confirm and pass through on ModuleSessionResumed after a disconnect',
        () {
      fakeAsync((async) {
        var fakeNow = DateTime(2024, 1, 1, 12, 0, 0);
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          clock: () => fakeNow,
          readyTimeout: const Duration(hours: 1),
        );

        // Start → disconnect → resume
        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();
        connectionCtrl.add(GrpcConnectionState.disconnected);
        async.flushMicrotasks();
        lifecycleCtrl.add(ModuleSessionResumed(moduleSessionId: 's1'));
        async.flushMicrotasks();

        // sendBatch should now work (cooldown reset by resume)
        sut.sendBatch([_sample(2)]);
        async.flushMicrotasks();

        expect(stub.callCount, 1);

        stub.latest.injectReady();
        async.flushMicrotasks();

        expect(stub.latest.batches.length, 1);
        expect(stub.latest.batches.first.samples.first.sessionId, 's1');

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });
  });

  // ── Phase 2: Stream-through-pause ─────────────────────────────────────────

  group('BiometricStreamClient — pause does not gate sends', () {
    test('should keep sending while paused', () {
      fakeAsync((async) {
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          readyTimeout: const Duration(hours: 1),
        );

        // Start, open stream, drive ready
        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();
        sut.sendBatch([_sample(0)]); // opens stream + buffers
        async.flushMicrotasks();
        stub.latest.injectReady();
        async.flushMicrotasks(); // drain sample 0

        final batchesBeforePause = stub.latest.batches.length;

        // Pause
        lifecycleCtrl.add(ModuleSessionPaused());
        async.flushMicrotasks();

        sut.sendBatch([_sample(1)]);
        async.flushMicrotasks();

        expect(stub.latest.batches.length, batchesBeforePause + 1);
        expect(stub.latest.batches.last.samples.first.timestamp.toInt(), 1);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });

    test('should keep sending after unpause', () {
      fakeAsync((async) {
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          readyTimeout: const Duration(hours: 1),
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();
        sut.sendBatch([_sample(0)]);
        async.flushMicrotasks();
        stub.latest.injectReady();
        async.flushMicrotasks();

        final batchesAfterReady = stub.latest.batches.length;

        lifecycleCtrl.add(ModuleSessionPaused());
        async.flushMicrotasks();
        lifecycleCtrl.add(ModuleSessionUnpaused());
        async.flushMicrotasks();

        sut.sendBatch([_sample(2)]);
        async.flushMicrotasks();

        expect(stub.latest.batches.length, batchesAfterReady + 1);
        expect(stub.latest.batches.last.samples.first.timestamp.toInt(), 2);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });
  });

  // ── Phase 3: Readiness gate and replay-ring drain ─────────────────────────

  group('BiometricStreamClient — readiness gate and drain', () {
    test(
        'should buffer samples to the replay ring while the stream is open but not ready',
        () {
      fakeAsync((async) {
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          readyTimeout: const Duration(hours: 1),
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();

        sut.sendBatch([_sample(1), _sample(2), _sample(3)]);
        async.flushMicrotasks();

        // Stream opened but not ready — nothing should be in the sink yet
        expect(stub.callCount, 1);
        expect(stub.latest.batches, isEmpty);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });

    test('should drain the buffered ring in FIFO order when the server emits ready',
        () {
      fakeAsync((async) {
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          readyTimeout: const Duration(hours: 1),
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();

        sut.sendBatch([_sample(1), _sample(2), _sample(3)]);
        async.flushMicrotasks();

        stub.latest.injectReady();
        async.flushMicrotasks();

        expect(stub.latest.batches.length, 1);
        final timestamps = stub.latest.batches.first.samples
            .map((s) => s.timestamp.toInt())
            .toList();
        expect(timestamps, [1, 2, 3]);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });

    test('should send directly to the sink once ready', () {
      fakeAsync((async) {
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          readyTimeout: const Duration(hours: 1),
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();
        sut.sendBatch([_sample(1)]);
        async.flushMicrotasks();
        stub.latest.injectReady();
        async.flushMicrotasks(); // drain s1

        final batchCountAfterDrain = stub.latest.batches.length;

        sut.sendBatch([_sample(4)]);
        async.flushMicrotasks();

        // s4 should appear immediately as a new batch
        expect(stub.latest.batches.length, batchCountAfterDrain + 1);
        expect(stub.latest.batches.last.samples.first.timestamp.toInt(), 4);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });

    test('should not re-send drained samples', () {
      fakeAsync((async) {
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          readyTimeout: const Duration(hours: 1),
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();

        sut.sendBatch([_sample(1), _sample(2), _sample(3)]);
        async.flushMicrotasks();
        stub.latest.injectReady();
        async.flushMicrotasks(); // drains s1..s3 in one batch

        sut.sendBatch([_sample(4)]);
        async.flushMicrotasks();

        // Exactly 2 batches total: drain batch (s1..s3) + direct batch (s4)
        expect(stub.latest.batches.length, 2);
        final secondBatchTimestamps = stub.latest.batches[1].samples
            .map((s) => s.timestamp.toInt())
            .toList();
        expect(secondBatchTimestamps, [4]);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });
  });

  // ── Phase 3 (Task 4): Reconnect re-gates readiness ────────────────────────

  group('BiometricStreamClient — reconnect re-gates', () {
    test(
        'should re-gate after reconnect so post-reconnect samples buffer until a new ready',
        () {
      fakeAsync((async) {
        var fakeNow = DateTime(2024, 1, 1, 12, 0, 0);
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          clock: () => fakeNow,
          readyTimeout: const Duration(hours: 1),
        );

        // 1. Start → open → ready → send flows
        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();
        sut.sendBatch([_sample(1)]);
        async.flushMicrotasks();
        stub.connections[0].injectReady();
        async.flushMicrotasks();
        expect(stub.connections[0].batches.length, 1); // s1 sent

        // 2. Disconnect → teardown
        connectionCtrl.add(GrpcConnectionState.disconnected);
        async.flushMicrotasks();

        // 3. Resume → re-confirm + reset cooldown
        lifecycleCtrl.add(ModuleSessionResumed(moduleSessionId: 's1'));
        async.flushMicrotasks();

        // 4. Advance clock past 2 s (belt-and-suspenders)
        fakeNow = fakeNow.add(const Duration(seconds: 3));
        async.elapse(const Duration(seconds: 3));

        // 5. sendBatch opens fresh stream but no ready yet → buffer
        sut.sendBatch([_sample(2)]);
        async.flushMicrotasks();

        expect(stub.callCount, 2);
        expect(stub.connections[1].batches, isEmpty); // s2 buffered

        // 6. New ready → drains s2
        stub.connections[1].injectReady();
        async.flushMicrotasks();

        expect(stub.connections[1].batches.length, 1);
        expect(
            stub.connections[1].batches.first.samples.first.timestamp.toInt(),
            2);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });
  });

  // ── Phase 4: Replay-ring bound (cap 75, drop-oldest) ─────────────────────

  group('BiometricStreamClient — replay ring cap', () {
    test('should retain exactly 75 samples and drop the oldest when over capacity',
        () {
      fakeAsync((async) {
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          readyTimeout: const Duration(hours: 1),
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();

        // Buffer 76 samples; ts=1 should be evicted
        sut.sendBatch(List.generate(76, (i) => _sample(i + 1)));
        async.flushMicrotasks();

        stub.latest.injectReady();
        async.flushMicrotasks();

        expect(stub.latest.batches.length, 1);
        final drained = stub.latest.batches.first.samples;
        expect(drained.length, 75);
        expect(drained.first.timestamp.toInt(), 2); // oldest dropped (ts=1)
        expect(drained.last.timestamp.toInt(), 76);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });

    test('should preserve FIFO order of the retained window after dropping', () {
      fakeAsync((async) {
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          readyTimeout: const Duration(hours: 1),
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();

        sut.sendBatch(List.generate(76, (i) => _sample(i + 1)));
        async.flushMicrotasks();

        stub.latest.injectReady();
        async.flushMicrotasks();

        final timestamps = stub.latest.batches.first.samples
            .map((s) => s.timestamp.toInt())
            .toList();
        expect(timestamps, List.generate(75, (i) => i + 2)); // 2..76 ascending

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });
  });

  // ── Phase 5: Reopen cooldown (2 s) ────────────────────────────────────────

  group('BiometricStreamClient — reopen cooldown', () {
    test('should open the stream on the first send without cooldown delay', () {
      fakeAsync((async) {
        var fakeNow = DateTime(2024, 1, 1, 12, 0, 0);
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          clock: () => fakeNow,
          readyTimeout: const Duration(hours: 1),
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();

        sut.sendBatch([_sample(1)]);
        async.flushMicrotasks();

        expect(stub.callCount, 1);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });

    test('should not reopen within 2 s of a teardown', () {
      fakeAsync((async) {
        var fakeNow = DateTime(2024, 1, 1, 12, 0, 0);
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          clock: () => fakeNow,
          readyTimeout: const Duration(hours: 1),
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();

        // Open stream → _lastOpenAttempt = T=0
        sut.sendBatch([_sample(1)]);
        async.flushMicrotasks();
        expect(stub.callCount, 1);

        // Teardown → sink=null but _lastOpenAttempt unchanged (T=0)
        connectionCtrl.add(GrpcConnectionState.disconnected);
        async.flushMicrotasks();

        // Advance 0.5 s — still within 2 s cooldown
        fakeNow = fakeNow.add(const Duration(milliseconds: 500));
        async.elapse(const Duration(milliseconds: 500));

        // Trigger reopen via `connected` (no SessionStarted — must not reset cooldown)
        connectionCtrl.add(GrpcConnectionState.connected);
        async.flushMicrotasks();

        // Cooldown active → no new stream
        expect(stub.callCount, 1);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });

    test('should allow reopen after 2 s have elapsed', () {
      fakeAsync((async) {
        var fakeNow = DateTime(2024, 1, 1, 12, 0, 0);
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          clock: () => fakeNow,
          readyTimeout: const Duration(hours: 1),
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();

        sut.sendBatch([_sample(1)]);
        async.flushMicrotasks();
        expect(stub.callCount, 1);

        connectionCtrl.add(GrpcConnectionState.disconnected);
        async.flushMicrotasks();

        // Advance past 2 s cooldown (no SessionStarted — must not reset cooldown)
        fakeNow = fakeNow.add(const Duration(milliseconds: 2100));
        async.elapse(const Duration(milliseconds: 2100));

        // Trigger reopen via `connected`
        connectionCtrl.add(GrpcConnectionState.connected);
        async.flushMicrotasks();

        expect(stub.callCount, 2);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });

    test(
        'should reset the cooldown on ModuleSessionStarted so stream reopens immediately',
        () {
      fakeAsync((async) {
        var fakeNow = DateTime(2024, 1, 1, 12, 0, 0);
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          clock: () => fakeNow,
          readyTimeout: const Duration(hours: 1),
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();

        sut.sendBatch([_sample(1)]);
        async.flushMicrotasks();
        expect(stub.callCount, 1);

        connectionCtrl.add(GrpcConnectionState.disconnected);
        async.flushMicrotasks();

        // Still within 2 s window
        fakeNow = fakeNow.add(const Duration(milliseconds: 500));
        async.elapse(const Duration(milliseconds: 500));

        // ModuleSessionStarted resets _lastOpenAttempt = null
        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();

        // sendBatch should open immediately despite < 2 s elapsed since teardown
        sut.sendBatch([_sample(2)]);
        async.flushMicrotasks();

        expect(stub.callCount, 2);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });
  });

  // ── Phase 6: Readiness fallback timer ────────────────────────────────────

  group('BiometricStreamClient — readiness fallback timer', () {
    test('should auto-drain the replay ring when no ready arrives within readyTimeout',
        () {
      fakeAsync((async) {
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        const timeout = Duration(milliseconds: 10);
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          readyTimeout: timeout,
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();

        sut.sendBatch([_sample(1), _sample(2)]);
        async.flushMicrotasks();

        // Nothing in sink yet
        expect(stub.latest.batches, isEmpty);

        // Elapse past the fallback timeout → ring drains
        async.elapse(timeout);
        async.flushMicrotasks();

        expect(stub.latest.batches.length, 1);
        expect(stub.latest.batches.first.samples.length, 2);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });

    test('should send directly after the fallback fires', () {
      fakeAsync((async) {
        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        const timeout = Duration(milliseconds: 10);
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          readyTimeout: timeout,
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();

        sut.sendBatch([_sample(1), _sample(2)]);
        async.flushMicrotasks();

        async.elapse(timeout);
        async.flushMicrotasks(); // timeout fires → drains s1+s2

        final batchCountAfterTimeout = stub.latest.batches.length;

        sut.sendBatch([_sample(3)]);
        async.flushMicrotasks();

        // s3 should be sent immediately (gate forced open by timeout)
        expect(stub.latest.batches.length, batchCountAfterTimeout + 1);
        expect(stub.latest.batches.last.samples.first.timestamp.toInt(), 3);

        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });

    test('should log a readiness-timeout warning when the fallback fires', () {
      fakeAsync((async) {
        final logs = <String>[];
        final originalPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) logs.add(message);
        };

        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        const timeout = Duration(milliseconds: 10);
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          readyTimeout: timeout,
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();

        sut.sendBatch([_sample(1)]);
        async.flushMicrotasks();

        async.elapse(timeout);
        async.flushMicrotasks();

        expect(
          logs.any((l) =>
              l.contains('readiness timeout — draining without server ready')),
          isTrue,
          reason: 'Expected readiness-timeout warning to be logged once',
        );

        debugPrint = originalPrint;
        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });

    test('should NOT fire the fallback when ready arrives first', () {
      fakeAsync((async) {
        final logs = <String>[];
        final originalPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) logs.add(message);
        };

        final stub = _FakeStub();
        final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
        final connectionCtrl =
            StreamController<GrpcConnectionState>.broadcast();
        const timeout = Duration(milliseconds: 10);
        final sut = BiometricStreamClient(
          grpcStub: stub,
          moduleStateEvents: lifecycleCtrl.stream,
          connectionState: connectionCtrl.stream,
          readyTimeout: timeout,
        );

        lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 's1'));
        async.flushMicrotasks();

        sut.sendBatch([_sample(1)]);
        async.flushMicrotasks();

        // Inject ready BEFORE timeout
        stub.latest.injectReady();
        async.flushMicrotasks(); // ready processed → _isReady=true, timer cancelled

        final batchCountAfterReady = stub.latest.batches.length;

        // Elapse past timeout — cancelled timer must NOT fire
        async.elapse(const Duration(milliseconds: 20));
        async.flushMicrotasks();

        // No timeout warning
        expect(
          logs.any((l) =>
              l.contains('readiness timeout — draining without server ready')),
          isFalse,
          reason: 'Timeout warning should not be logged when ready arrived first',
        );

        // No double-drain: batch count unchanged since ready
        expect(stub.latest.batches.length, batchCountAfterReady);

        debugPrint = originalPrint;
        sut.dispose();
        lifecycleCtrl.close();
        connectionCtrl.close();
      });
    });
  });
}
