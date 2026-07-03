import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/service_api.dart' as $grpc;

import 'package:mind/Biometrics/BioSample.dart';
import 'package:mind/Biometrics/BiometricStreamClient.dart';
import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
import 'package:mind/Core/Grpc/ModuleStateEvent.dart';
import 'package:mind/Core/Grpc/generated/module_biometric_stream.pbgrpc.dart'
    as $bio;

// ---------------------------------------------------------------------------
// Fakes (mirrored from biometric_stream_client_test.dart — golden master;
// copied, not imported, so this file stays self-contained and that file is
// never edited)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Tests
//
// These pin the root/child bio id-routing contract (note 23) ahead of the
// note-17 implementation. Each test below is annotated RED-now/GREEN-now.
// ---------------------------------------------------------------------------

void main() {
  group('BiometricStreamClient — bio id-routing (root/child)', () {
    test(
      // RED now: current code tags samples with the child id from
      // _onLifecycleEvent; goes GREEN under note 17 (bio sourced from root id).
      'should tag the bio sample with root.id, not the child id',
      () {
        fakeAsync((async) {
          final stub = _FakeStub();
          final rootIdCtrl = StreamController<String?>.broadcast();
          final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
          final connectionCtrl =
              StreamController<GrpcConnectionState>.broadcast();
          final sut = BiometricStreamClient(
            grpcStub: stub,
            moduleStateEvents: lifecycleCtrl.stream,
            connectionState: connectionCtrl.stream,
            rootIdChanges: rootIdCtrl.stream,
            readyTimeout: const Duration(hours: 1),
          );

          rootIdCtrl.add('root-1');
          async.flushMicrotasks();
          lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 'child-A'));
          async.flushMicrotasks();

          sut.sendBatch([_sample(1)]);
          async.flushMicrotasks();
          stub.latest.injectReady();
          async.flushMicrotasks();

          expect(stub.latest.batches, isNotEmpty);
          expect(stub.latest.batches.first.samples.first.sessionId, 'root-1');

          sut.dispose();
          rootIdCtrl.close();
          lifecycleCtrl.close();
          connectionCtrl.close();
        });
      },
    );

    test(
      // RED now: current _onLifecycleEvent clears _currentSessionId on
      // ModuleSessionEnded → sendBatch becomes a no-op → no batch is sent.
      // Goes GREEN under note 17 (child end must not clear the root-sourced id).
      'should NOT clear the bio id when the child ends — bio keeps flowing under root.id',
      () {
        fakeAsync((async) {
          final stub = _FakeStub();
          final rootIdCtrl = StreamController<String?>.broadcast();
          final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
          final connectionCtrl =
              StreamController<GrpcConnectionState>.broadcast();
          final sut = BiometricStreamClient(
            grpcStub: stub,
            moduleStateEvents: lifecycleCtrl.stream,
            connectionState: connectionCtrl.stream,
            rootIdChanges: rootIdCtrl.stream,
            readyTimeout: const Duration(hours: 1),
          );

          rootIdCtrl.add('root-1');
          async.flushMicrotasks();
          lifecycleCtrl.add(ModuleSessionStarted(moduleSessionId: 'child-A'));
          async.flushMicrotasks();
          lifecycleCtrl.add(ModuleSessionEnded());
          async.flushMicrotasks();

          sut.sendBatch([_sample(1)]);
          async.flushMicrotasks();

          // Assert the stream actually opened before touching `stub.latest` —
          // otherwise a still-clearing bio id crashes here on `connections.last`
          // instead of failing with a readable RED diagnostic.
          expect(stub.callCount, greaterThan(0),
              reason: 'expected bio to keep sending under root-1 after the '
                  'child ended; currently _onLifecycleEvent clears the '
                  'session id on ModuleSessionEnded, so no stream opens (RED)');

          stub.latest.injectReady();
          async.flushMicrotasks();

          expect(stub.latest.batches, isNotEmpty);
          expect(stub.latest.batches.first.samples.first.sessionId, 'root-1');

          sut.dispose();
          rootIdCtrl.close();
          lifecycleCtrl.close();
          connectionCtrl.close();
        });
      },
    );

    test(
      // RED now: the seam is unwired, so the precondition step ("send flows
      // under root-1") never happens — the batch assertion below never sees
      // a first batch. Goes GREEN under note 17 (global reset — root gone —
      // clears the bio id and empties the replay ring).
      'should clear the bio id and stop accumulating replay when the root is gone (rootIdChanges emits null)',
      () {
        fakeAsync((async) {
          final stub = _FakeStub();
          final rootIdCtrl = StreamController<String?>.broadcast();
          final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
          final connectionCtrl =
              StreamController<GrpcConnectionState>.broadcast();
          final sut = BiometricStreamClient(
            grpcStub: stub,
            moduleStateEvents: lifecycleCtrl.stream,
            connectionState: connectionCtrl.stream,
            rootIdChanges: rootIdCtrl.stream,
            readyTimeout: const Duration(hours: 1),
          );

          rootIdCtrl.add('root-1');
          async.flushMicrotasks();

          // Buffer a sample while the stream is open but not yet ready, so it
          // lands in the replay ring rather than being sent directly.
          sut.sendBatch([_sample(1)]);
          async.flushMicrotasks();

          // Assert the stream actually opened before touching `stub.latest` —
          // otherwise the still-unwired seam crashes here on `connections.last`
          // instead of failing with a readable RED diagnostic.
          expect(stub.callCount, greaterThan(0),
              reason: 'expected bio to open a stream and buffer under root-1; '
                  'currently the seam is unwired so the gate never opens (RED)');
          expect(stub.latest.batches, isEmpty,
              reason: 'sample(1) should be buffered in the replay ring, not sent yet');
          final callCountBeforeReset = stub.callCount;

          // Root gone — must clear the bio id AND empty the replay ring.
          rootIdCtrl.add(null);
          async.flushMicrotasks();

          // Server becomes ready on the still-open connection: if the replay
          // ring were not cleared on reset, the buffered sample(1) would drain
          // here. Directly proves "ring emptied", not just "nothing new sent".
          stub.latest.injectReady();
          async.flushMicrotasks();
          expect(stub.latest.batches, isEmpty,
              reason: 'replay ring must be emptied when the root is gone — '
                  'a buffered sample must not survive the reset');

          sut.sendBatch([_sample(2)]);
          async.flushMicrotasks();

          // No further stream opened either — the gate stays closed post-reset.
          expect(stub.callCount, callCountBeforeReset);

          sut.dispose();
          rootIdCtrl.close();
          lifecycleCtrl.close();
          connectionCtrl.close();
        });
      },
    );

    test(
      // Guard — expected GREEN now and after note 17: bio is held until the
      // root id is known; no lifecycle start alone should be enough.
      'should hold — no bio is sent before rootId is known (gate guard)',
      () {
        fakeAsync((async) {
          final stub = _FakeStub();
          final rootIdCtrl = StreamController<String?>.broadcast();
          final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
          final connectionCtrl =
              StreamController<GrpcConnectionState>.broadcast();
          final sut = BiometricStreamClient(
            grpcStub: stub,
            moduleStateEvents: lifecycleCtrl.stream,
            connectionState: connectionCtrl.stream,
            rootIdChanges: rootIdCtrl.stream,
            readyTimeout: const Duration(hours: 1),
          );

          // No rootIdChanges emission and no lifecycle start.
          sut.sendBatch([_sample(1)]);
          async.flushMicrotasks();

          expect(stub.callCount, 0);

          sut.dispose();
          rootIdCtrl.close();
          lifecycleCtrl.close();
          connectionCtrl.close();
        });
      },
    );

    test(
      // Reconnect hazard (plan review 1): `rootIdChanges` is `.distinct()`, so
      // a transient gRPC reconnect that re-sends the same idempotent root.id
      // never re-enters `_onRootIdChanged`. A disconnect must not be treated
      // as "root gone" in root-sourced mode, or bio would silently stop for
      // the rest of the session.
      'bio keeps flowing under root.id across a disconnect/reconnect (no rootIdChanges re-emission)',
      () {
        fakeAsync((async) {
          var fakeNow = DateTime(2024, 1, 1, 12, 0, 0);
          final stub = _FakeStub();
          final rootIdCtrl = StreamController<String?>.broadcast();
          final lifecycleCtrl = StreamController<ModuleStateEvent>.broadcast();
          final connectionCtrl =
              StreamController<GrpcConnectionState>.broadcast();
          final sut = BiometricStreamClient(
            grpcStub: stub,
            moduleStateEvents: lifecycleCtrl.stream,
            connectionState: connectionCtrl.stream,
            rootIdChanges: rootIdCtrl.stream,
            clock: () => fakeNow,
            readyTimeout: const Duration(hours: 1),
          );

          // 1. Root known → open → ready → send flows under root-1.
          rootIdCtrl.add('root-1');
          async.flushMicrotasks();

          sut.sendBatch([_sample(1)]);
          async.flushMicrotasks();
          stub.latest.injectReady();
          async.flushMicrotasks();

          expect(stub.latest.batches, isNotEmpty);
          expect(stub.latest.batches.first.samples.first.sessionId, 'root-1');

          // 2. Transient disconnect/reconnect — rootIdChanges does NOT
          // re-emit (`.distinct()` would suppress a redundant 'root-1').
          connectionCtrl.add(GrpcConnectionState.disconnected);
          async.flushMicrotasks();

          // Advance the injected clock past the 2 s reopen cooldown between
          // teardown and reopen (fakeAsync does not freeze DateTime.now).
          fakeNow = fakeNow.add(const Duration(seconds: 3));
          async.elapse(const Duration(seconds: 3));

          connectionCtrl.add(GrpcConnectionState.connected);
          async.flushMicrotasks();

          // 3. Send again — a fresh stream must open and, once ready, the
          // batch must still flow under root-1: _sessionConfirmed was not
          // stuck false by the disconnect clear.
          sut.sendBatch([_sample(2)]);
          async.flushMicrotasks();

          expect(stub.callCount, 2);

          stub.latest.injectReady();
          async.flushMicrotasks();

          expect(stub.latest.batches, isNotEmpty);
          expect(stub.latest.batches.first.samples.first.sessionId, 'root-1');

          sut.dispose();
          rootIdCtrl.close();
          lifecycleCtrl.close();
          connectionCtrl.close();
        });
      },
    );
  });
}
