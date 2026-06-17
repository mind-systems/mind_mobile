import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mind/Biometrics/BioSample.dart';
import 'package:mind/Biometrics/BioStreamRouter.dart';
import 'package:mind/Biometrics/BiometricBatcher.dart';
import 'package:mind/Biometrics/BiometricStreamClient.dart';
import 'package:mind/Biometrics/IHeartRateSource.dart';
import 'package:mind/Biometrics/IRrIntervalSource.dart';
import 'package:mind/Biometrics/IEegBandsSource.dart';
import 'package:mind/Biometrics/IEmotionsSource.dart';
import 'package:mind/Biometrics/IMotionSource.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeBioStreamRouter implements BioStreamRouter {
  final _controller = StreamController<BioSample>.broadcast();

  void emit(BioSample sample) => _controller.add(sample);

  @override
  Stream<BioSample> get samples => _controller.stream;

  @override
  void registerHeartRateSource(IHeartRateSource source) {}

  @override
  void registerRrIntervalSource(IRrIntervalSource source) {}

  @override
  void registerEegBandsSource(IEegBandsSource source) {}

  @override
  void registerEmotionsSource(IEmotionsSource source) {}

  @override
  void registerMotionSource(IMotionSource source) {}
}

class _FakeBiometricStreamClient implements BiometricStreamClient {
  final List<List<BioSample>> batches = [];

  @override
  void sendBatch(List<BioSample> samples) => batches.add(samples);

  @override
  Future<void> dispose() async {}
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

BioSample _sample(int timestampMs) =>
    BioSample(timestampMs: timestampMs, sampleType: 'rr', data: const {});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Task 1: Size-based flush ──────────────────────────────────────────────

  group('BiometricBatcher — size-based flush', () {
    late _FakeBioStreamRouter fakeRouter;
    late _FakeBiometricStreamClient fakeClient;
    late BiometricBatcher sut;

    setUp(() {
      fakeRouter = _FakeBioStreamRouter();
      fakeClient = _FakeBiometricStreamClient();
      sut = BiometricBatcher(
        router: fakeRouter,
        client: fakeClient,
        flushInterval: const Duration(seconds: 10),
        maxBatchSize: 3,
      );
      addTearDown(() => sut.dispose());
    });

    test(
      'should not flush when buffer has fewer than maxBatchSize samples',
      () async {
        fakeRouter.emit(_sample(1));
        fakeRouter.emit(_sample(2));
        await Future<void>.delayed(Duration.zero);

        expect(fakeClient.batches, isEmpty);
      },
    );

    test(
      'should flush immediately when buffer reaches maxBatchSize',
      () async {
        fakeRouter.emit(_sample(1));
        fakeRouter.emit(_sample(2));
        fakeRouter.emit(_sample(3));
        await Future<void>.delayed(Duration.zero);

        expect(fakeClient.batches.length, 1);
        expect(fakeClient.batches.first.length, 3);
      },
    );

    test(
      'should clear buffer after a size flush',
      () async {
        fakeRouter.emit(_sample(1));
        fakeRouter.emit(_sample(2));
        fakeRouter.emit(_sample(3));
        await Future<void>.delayed(Duration.zero);
        // first flush
        expect(fakeClient.batches.length, 1);

        fakeRouter.emit(_sample(4));
        fakeRouter.emit(_sample(5));
        fakeRouter.emit(_sample(6));
        await Future<void>.delayed(Duration.zero);

        expect(fakeClient.batches.length, 2);
        expect(fakeClient.batches[1].length, 3);
      },
    );

    test(
      'should preserve FIFO order in the flushed batch',
      () async {
        fakeRouter.emit(_sample(1));
        fakeRouter.emit(_sample(2));
        fakeRouter.emit(_sample(3));
        await Future<void>.delayed(Duration.zero);

        final batch = fakeClient.batches.first;
        expect(batch.map((s) => s.timestampMs).toList(), [1, 2, 3]);
      },
    );

    test(
      'should send an unmodifiable batch to the client',
      () async {
        fakeRouter.emit(_sample(1));
        fakeRouter.emit(_sample(2));
        fakeRouter.emit(_sample(3));
        await Future<void>.delayed(Duration.zero);

        final batch = fakeClient.batches.first;
        expect(
          () => batch.add(_sample(99)),
          throwsUnsupportedError,
        );
      },
    );
  });

  // ── Task 2: Timer-based deadline flush ────────────────────────────────────

  group('BiometricBatcher — timer-based deadline flush', () {
    const flushInterval = Duration(milliseconds: 1);

    test(
      'should not flush before the flush interval elapses',
      () {
        fakeAsync((async) {
          final fakeRouter = _FakeBioStreamRouter();
          final fakeClient = _FakeBiometricStreamClient();
          final sut = BiometricBatcher(
            router: fakeRouter,
            client: fakeClient,
            flushInterval: flushInterval,
            maxBatchSize: 3,
          );

          fakeRouter.emit(_sample(1));
          fakeRouter.emit(_sample(2));
          async.flushMicrotasks();

          expect(fakeClient.batches, isEmpty);

          sut.dispose();
        });
      },
    );

    test(
      'should flush the partial buffer when the flush interval elapses',
      () {
        fakeAsync((async) {
          final fakeRouter = _FakeBioStreamRouter();
          final fakeClient = _FakeBiometricStreamClient();
          final sut = BiometricBatcher(
            router: fakeRouter,
            client: fakeClient,
            flushInterval: flushInterval,
            maxBatchSize: 3,
          );

          fakeRouter.emit(_sample(1));
          fakeRouter.emit(_sample(2));
          async.flushMicrotasks();

          async.elapse(flushInterval);

          expect(fakeClient.batches.length, 1);
          expect(fakeClient.batches.first.length, 2);

          sut.dispose();
        });
      },
    );

    test(
      'should clear the buffer after a timer flush',
      () {
        fakeAsync((async) {
          final fakeRouter = _FakeBioStreamRouter();
          final fakeClient = _FakeBiometricStreamClient();
          final sut = BiometricBatcher(
            router: fakeRouter,
            client: fakeClient,
            flushInterval: flushInterval,
            maxBatchSize: 3,
          );

          fakeRouter.emit(_sample(1));
          fakeRouter.emit(_sample(2));
          async.flushMicrotasks();
          async.elapse(flushInterval);
          // first batch of 2

          fakeRouter.emit(_sample(3));
          async.flushMicrotasks();
          async.elapse(flushInterval);
          // second batch of 1

          expect(fakeClient.batches.length, 2);
          expect(fakeClient.batches[0].length, 2);
          expect(fakeClient.batches[1].length, 1);

          sut.dispose();
        });
      },
    );
  });

  // ── Task 3: Timer lifecycle invariants ────────────────────────────────────

  group('BiometricBatcher — timer lifecycle invariants', () {
    const flushInterval = Duration(milliseconds: 1);

    test(
      'should not start a second timer when a sample arrives before the deadline',
      () {
        fakeAsync((async) {
          final fakeRouter = _FakeBioStreamRouter();
          final fakeClient = _FakeBiometricStreamClient();
          final sut = BiometricBatcher(
            router: fakeRouter,
            client: fakeClient,
            flushInterval: flushInterval,
            maxBatchSize: 3,
          );

          fakeRouter.emit(_sample(1));
          async.flushMicrotasks();

          // Advance less than the full interval
          async.elapse(Duration.zero);

          fakeRouter.emit(_sample(2));
          async.flushMicrotasks();

          // Elapse to the first deadline
          async.elapse(flushInterval);

          // Single batch of 2, no duplicate flush
          expect(fakeClient.batches.length, 1);
          expect(fakeClient.batches.first.length, 2);

          // No additional timer fires after the deadline
          async.elapse(flushInterval);
          expect(fakeClient.batches.length, 1);

          sut.dispose();
        });
      },
    );

    test(
      'should cancel the pending timer when a size flush occurs first',
      () {
        fakeAsync((async) {
          final fakeRouter = _FakeBioStreamRouter();
          final fakeClient = _FakeBiometricStreamClient();
          final sut = BiometricBatcher(
            router: fakeRouter,
            client: fakeClient,
            flushInterval: flushInterval,
            maxBatchSize: 3,
          );

          // Emit 1 to arm the timer, then fill the batch to trigger size flush
          fakeRouter.emit(_sample(1));
          async.flushMicrotasks();
          fakeRouter.emit(_sample(2));
          async.flushMicrotasks();
          fakeRouter.emit(_sample(3));
          async.flushMicrotasks();
          // size flush fires — 1 batch

          expect(fakeClient.batches.length, 1);

          // Elapse past the old timer deadline — should not produce extra empty batch
          async.elapse(flushInterval);

          expect(fakeClient.batches.length, 1);

          sut.dispose();
        });
      },
    );

    test(
      'should start a fresh timer for samples buffered after a flush',
      () {
        fakeAsync((async) {
          final fakeRouter = _FakeBioStreamRouter();
          final fakeClient = _FakeBiometricStreamClient();
          final sut = BiometricBatcher(
            router: fakeRouter,
            client: fakeClient,
            flushInterval: flushInterval,
            maxBatchSize: 3,
          );

          // First flush via timer
          fakeRouter.emit(_sample(1));
          async.flushMicrotasks();
          async.elapse(flushInterval);
          expect(fakeClient.batches.length, 1);

          // Emit another sample after flush — a new timer should start
          fakeRouter.emit(_sample(2));
          async.flushMicrotasks();
          async.elapse(flushInterval);

          expect(fakeClient.batches.length, 2);
          expect(fakeClient.batches[1].length, 1);

          sut.dispose();
        });
      },
    );
  });

  // ── Task 4: Dispose behavior ──────────────────────────────────────────────

  group('BiometricBatcher — dispose', () {
    test(
      'should flush remaining buffered samples on dispose',
      () async {
        final fakeRouter = _FakeBioStreamRouter();
        final fakeClient = _FakeBiometricStreamClient();
        final sut = BiometricBatcher(
          router: fakeRouter,
          client: fakeClient,
          flushInterval: const Duration(seconds: 10),
          maxBatchSize: 3,
        );

        fakeRouter.emit(_sample(1));
        fakeRouter.emit(_sample(2));
        await Future<void>.delayed(Duration.zero);

        await sut.dispose();

        expect(fakeClient.batches.length, 1);
        expect(fakeClient.batches.first.length, 2);
      },
    );

    test(
      'should not call sendBatch on dispose when the buffer is empty',
      () async {
        final fakeRouter = _FakeBioStreamRouter();
        final fakeClient = _FakeBiometricStreamClient();
        final sut = BiometricBatcher(
          router: fakeRouter,
          client: fakeClient,
          flushInterval: const Duration(seconds: 10),
          maxBatchSize: 3,
        );

        await sut.dispose();

        expect(fakeClient.batches, isEmpty);
      },
    );

    test(
      'should cancel the router subscription on dispose',
      () async {
        final fakeRouter = _FakeBioStreamRouter();
        final fakeClient = _FakeBiometricStreamClient();
        final sut = BiometricBatcher(
          router: fakeRouter,
          client: fakeClient,
          flushInterval: const Duration(seconds: 10),
          maxBatchSize: 3,
        );

        await sut.dispose();

        // emit after dispose — subscription is cancelled, no new batch
        fakeRouter.emit(_sample(1));
        fakeRouter.emit(_sample(2));
        fakeRouter.emit(_sample(3));
        await Future<void>.delayed(Duration.zero);

        expect(fakeClient.batches, isEmpty);
      },
    );

    test(
      'should cancel a pending flush timer on dispose',
      () {
        fakeAsync((async) {
          final fakeRouter = _FakeBioStreamRouter();
          final fakeClient = _FakeBiometricStreamClient();
          final sut = BiometricBatcher(
            router: fakeRouter,
            client: fakeClient,
            flushInterval: const Duration(milliseconds: 1),
            maxBatchSize: 3,
          );

          fakeRouter.emit(_sample(1));
          async.flushMicrotasks(); // let _onSample run → buffer = [s1], timer armed

          sut.dispose(); // async: flushes buffer then cancels timer

          // Elapse past the old timer deadline. During elapse, dispose's
          // async continuation runs (flushing the buffer and cancelling the
          // timer). Even if the timer fires before the cancel, _flushNow
          // returns early on an already-empty buffer.
          // Either way: exactly 1 batch — the dispose flush.
          async.elapse(const Duration(milliseconds: 2));

          expect(fakeClient.batches.length, 1);
          expect(fakeClient.batches.first.length, 1);
        });
      },
    );
  });
}
