import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';

import 'package:mind/Biometrics/ActiveRrSource.dart';
import 'package:mind/Biometrics/SmoothedRrSource.dart';
import 'package:mind/Biometrics/Models/RrInterval.dart';
import 'package:mind/Biometrics/Models/SensorSource.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeActiveRrSource implements ActiveRrSource {
  final _controller = StreamController<RrInterval>.broadcast();
  final _hasActiveSubject = BehaviorSubject<bool>.seeded(false);

  @override
  bool hasActiveSource = false;

  void emit(RrInterval rr) => _controller.add(rr);

  void emitHasActive(bool value) {
    hasActiveSource = value;
    _hasActiveSubject.add(value);
  }

  @override
  Stream<RrInterval> get stream => _controller.stream;

  @override
  Stream<bool> get hasActiveSourceStream => _hasActiveSubject.stream;

  Future<void> close() async {
    await _controller.close();
    await _hasActiveSubject.close();
  }

  // unused stubs
  @override
  Future<void> dispose() async => close();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

RrInterval _rr(int intervalMs, {bool isArtifact = false}) => RrInterval(
      intervalMs: intervalMs,
      timestamp: DateTime(2026, 1, 1),
      isArtifact: isArtifact,
      source: SensorSource.neiry,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeActiveRrSource source;
  late SmoothedRrSource sut;

  setUp(() {
    source = _FakeActiveRrSource();
  });

  tearDown(() async {
    await sut.dispose();
    await source.close();
  });

  // ── Task 1: Initial state ─────────────────────────────────────────────────

  group('SmoothedRrSource — initial state', () {
    setUp(() {
      sut = SmoothedRrSource(source);
    });

    test('should return null smoothedIntervalMs before any interval arrives', () {
      expect(sut.smoothedIntervalMs, isNull);
    });

    test('should not replay any value to a new subscriber before the first non-artifact interval', () async {
      final received = <int>[];
      sut.smoothedIntervalStream.listen(received.add);
      await Future<void>.delayed(Duration.zero);
      expect(received, isEmpty);
    });
  });

  // ── Task 2: SMA over non-artifact intervals ───────────────────────────────

  group('SmoothedRrSource — SMA over non-artifact intervals', () {
    setUp(() {
      sut = SmoothedRrSource(source);
    });

    test('should expose the single value as the SMA after one interval', () async {
      source.emit(_rr(500));
      await Future<void>.delayed(Duration.zero);
      expect(sut.smoothedIntervalMs, 500);
    });

    test('should average two intervals', () async {
      source.emit(_rr(500));
      source.emit(_rr(600));
      await Future<void>.delayed(Duration.zero);
      expect(sut.smoothedIntervalMs, 550);
    });

    test('should compute the SMA of the last 3 intervals once the window fills', () async {
      source.emit(_rr(500));
      source.emit(_rr(600));
      source.emit(_rr(700));
      await Future<void>.delayed(Duration.zero);
      expect(sut.smoothedIntervalMs, 600);
    });

    test('should drop the oldest sample once the window is full', () async {
      source.emit(_rr(500));
      source.emit(_rr(600));
      source.emit(_rr(700));
      source.emit(_rr(800));
      await Future<void>.delayed(Duration.zero);
      // window: [600, 700, 800] → avg 700
      expect(sut.smoothedIntervalMs, 700);
    });

    test('should emit a new SMA on smoothedIntervalStream for every non-artifact interval', () async {
      final received = <int>[];
      sut.smoothedIntervalStream.listen(received.add);

      source.emit(_rr(500));
      await Future<void>.delayed(Duration.zero);
      source.emit(_rr(600));
      await Future<void>.delayed(Duration.zero);
      source.emit(_rr(700));
      await Future<void>.delayed(Duration.zero);

      expect(received, [500, 550, 600]);
    });

    test('should replay the last SMA to a late subscriber', () async {
      source.emit(_rr(500));
      await Future<void>.delayed(Duration.zero);

      final received = <int>[];
      sut.smoothedIntervalStream.listen(received.add);
      await Future<void>.delayed(Duration.zero);

      expect(received, [500]);
    });

    test('should reflect only the latest interval when window is 1', () async {
      sut = SmoothedRrSource(source, window: 1);

      source.emit(_rr(500));
      await Future<void>.delayed(Duration.zero);
      expect(sut.smoothedIntervalMs, 500);

      source.emit(_rr(600));
      await Future<void>.delayed(Duration.zero);
      expect(sut.smoothedIntervalMs, 600);

      source.emit(_rr(700));
      await Future<void>.delayed(Duration.zero);
      expect(sut.smoothedIntervalMs, 700);
    });
  });

  // ── Task 3: Artifact filtering ────────────────────────────────────────────

  group('SmoothedRrSource — artifact filtering', () {
    setUp(() {
      sut = SmoothedRrSource(source);
    });

    test('should skip artifact intervals when computing the SMA', () async {
      source.emit(_rr(500));
      source.emit(_rr(9999, isArtifact: true));
      source.emit(_rr(600));
      source.emit(_rr(700));
      await Future<void>.delayed(Duration.zero);
      // window: [500, 600, 700] → avg 600
      expect(sut.smoothedIntervalMs, 600);
    });

    test('should not emit and keep smoothedIntervalMs null when only artifacts arrive', () async {
      final received = <int>[];
      sut.smoothedIntervalStream.listen(received.add);

      source.emit(_rr(9999, isArtifact: true));
      source.emit(_rr(8888, isArtifact: true));
      await Future<void>.delayed(Duration.zero);

      expect(received, isEmpty);
      expect(sut.smoothedIntervalMs, isNull);
    });
  });

  // ── Task 4: Availability pass-through ─────────────────────────────────────

  group('SmoothedRrSource — availability pass-through', () {
    setUp(() {
      sut = SmoothedRrSource(source);
    });

    test('should expose hasActiveSource from the underlying ActiveRrSource', () {
      source.hasActiveSource = true;
      expect(sut.hasActiveSource, isTrue);
    });

    test('should forward hasActiveSourceStream transitions from the underlying ActiveRrSource', () async {
      final received = <bool>[];
      sut.hasActiveSourceStream.skip(1).listen(received.add);

      source.emitHasActive(false);
      await Future<void>.delayed(Duration.zero);

      expect(received, [false]);
    });
  });

  // ── Task 5: Dispose ───────────────────────────────────────────────────────

  group('SmoothedRrSource — dispose', () {
    test('should close smoothedIntervalStream on dispose (subscribers receive done)', () async {
      sut = SmoothedRrSource(source);

      bool done = false;
      sut.smoothedIntervalStream.listen((_) {}, onDone: () => done = true);

      await sut.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
    });

    test('should stop accepting intervals after dispose', () async {
      sut = SmoothedRrSource(source);

      source.emit(_rr(500));
      await Future<void>.delayed(Duration.zero);
      final beforeDispose = sut.smoothedIntervalMs;

      await sut.dispose();

      // emit after dispose — should not throw, smoothedIntervalMs unchanged
      source.emit(_rr(999));
      await Future<void>.delayed(Duration.zero);

      expect(sut.smoothedIntervalMs, beforeDispose);
    });

    test('should not dispose or close the underlying ActiveRrSource', () async {
      sut = SmoothedRrSource(source);

      await sut.dispose();

      // The underlying fake stream should still be open
      bool gotData = false;
      final sub = source.stream.listen((_) => gotData = true);
      source.emit(_rr(500));
      await Future<void>.delayed(Duration.zero);

      expect(gotData, isTrue);
      await sub.cancel();
    });
  });
}
