import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';
import 'package:breath_module/breath_module.dart' show TickData, TickSource;

import 'package:mind/BreathModule/HeartRateTickService.dart';
import 'package:mind/Biometrics/SmoothedRrSource.dart';
import 'package:mind/Biometrics/Models/RrInterval.dart';
import 'package:mind/Biometrics/Models/SensorSource.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeSmoothedRrSource implements SmoothedRrSource {
  final _smoothedSubject = BehaviorSubject<int>();
  final _hasActiveSubject = BehaviorSubject<bool>.seeded(false);

  @override
  bool hasActiveSource = false;

  @override
  int? smoothedIntervalMs;

  void emitSmoothed(int ms) {
    smoothedIntervalMs = ms;
    _smoothedSubject.add(ms);
  }

  void seedSmoothed(int ms) {
    smoothedIntervalMs = ms;
    // Seed the subject so new subscribers get a replay immediately.
    _smoothedSubject.add(ms);
  }

  void emitHasActive(bool value) {
    hasActiveSource = value;
    _hasActiveSubject.add(value);
  }

  @override
  Stream<int> get smoothedIntervalStream => _smoothedSubject.stream;

  @override
  Stream<bool> get hasActiveSourceStream => _hasActiveSubject.stream;

  Future<void> close() async {
    await _smoothedSubject.close();
    await _hasActiveSubject.close();
  }

  // unused stubs
  @override
  Future<void> dispose() async => close();
}

class _FakeTimer implements Timer {
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
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
  // Spy timer factory — captures (delay, cb) tuples and returns FakeTimers.
  late List<({Duration delay, void Function() cb})> timers;
  late List<_FakeTimer> fakeTimers;

  Timer spyFactory(Duration d, void Function() cb) {
    final t = _FakeTimer();
    timers.add((delay: d, cb: cb));
    fakeTimers.add(t);
    return t;
  }

  // Find the timer whose delay matches the given Duration.
  _FakeTimer? _timerByDelay(Duration d) {
    for (var i = 0; i < timers.length; i++) {
      if (timers[i].delay == d) return fakeTimers[i];
    }
    return null;
  }

  void _fireByDelay(Duration d) {
    for (var i = 0; i < timers.length; i++) {
      if (timers[i].delay == d && !fakeTimers[i].cancelled) {
        timers[i].cb();
        return;
      }
    }
  }

  setUp(() {
    timers = [];
    fakeTimers = [];
  });

  // ── Task 6: Construction & seeding ───────────────────────────────────────

  group('HeartRateTickService — construction & seeding', () {
    test('should seed hasActiveSource true from the smoothed source on the warm path', () async {
      final source = _FakeSmoothedRrSource()
        ..hasActiveSource = true
        ..seedSmoothed(500);
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: const Duration(seconds: 10),
      );
      addTearDown(sut.dispose);

      expect(sut.hasActiveSource, isTrue);
    });

    test('should seed hasActiveSource false on the cold path', () async {
      final source = _FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: const Duration(seconds: 10),
      );
      addTearDown(sut.dispose);

      expect(sut.hasActiveSource, isFalse);
    });

    test('should arm the grace timer at construction on the warm path', () async {
      const grace = Duration(seconds: 10);
      final source = _FakeSmoothedRrSource()
        ..hasActiveSource = true
        ..seedSmoothed(500);
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      // Grace timer should already be captured before start().
      expect(_timerByDelay(grace), isNotNull);
      expect(_timerByDelay(grace)!.cancelled, isFalse);
    });

    test('should not arm the grace timer at construction on the cold path', () async {
      const grace = Duration(seconds: 10);
      final source = _FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      expect(_timerByDelay(grace), isNull);
    });

    test('should seed the metronome period from smoothedIntervalMs when available', () {
      const grace = Duration(seconds: 10);
      final source = _FakeSmoothedRrSource()
        ..hasActiveSource = true
        ..seedSmoothed(600);
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      sut.start();

      // Metronome uses non-grace delay: 600 ms
      expect(_timerByDelay(const Duration(milliseconds: 600)), isNotNull);
    });

    test('should default the metronome period to 1000 ms when smoothedIntervalMs is null', () {
      const grace = Duration(seconds: 10);
      final source = _FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      sut.start();

      expect(_timerByDelay(const Duration(milliseconds: 1000)), isNotNull);
    });
  });

  // ── Task 7: Metronome lifecycle ───────────────────────────────────────────

  group('HeartRateTickService — metronome lifecycle', () {
    const grace = Duration(seconds: 10);

    test('should not schedule the metronome or emit ticks before start() is called', () async {
      final source = _FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      final ticks = <TickData>[];
      sut.tickStream.listen(ticks.add);

      source.emitSmoothed(600);
      await Future<void>.delayed(Duration.zero);

      // Genuine beat may arm a grace timer, but no metronome should be scheduled.
      final nonGraceTimers = timers.where((t) => t.delay != grace).toList();
      expect(nonGraceTimers, isEmpty);
      expect(ticks, isEmpty);
    });

    test('should emit no immediate/prime tick when start() is called', () async {
      final source = _FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      final ticks = <TickData>[];
      sut.tickStream.listen(ticks.add);

      sut.start();
      await Future<void>.delayed(Duration.zero);

      expect(ticks, isEmpty);
    });

    test('should emit a tick with the current period when the metronome fires', () async {
      final source = _FakeSmoothedRrSource()..seedSmoothed(600)..hasActiveSource = true;
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      final ticks = <TickData>[];
      sut.tickStream.listen(ticks.add);

      sut.start();

      // Find and fire the metronome (600 ms delay).
      _fireByDelay(const Duration(milliseconds: 600));
      await Future<void>.delayed(Duration.zero);

      expect(ticks.length, 1);
      expect(ticks.first.intervalMs, 600);
    });

    test('should reschedule the metronome after each fire', () async {
      final source = _FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      sut.start();
      final countBefore = timers.length;

      _fireByDelay(const Duration(milliseconds: 1000));
      await Future<void>.delayed(Duration.zero);

      expect(timers.length, greaterThan(countBefore));
    });

    test('should clamp the period to the 250 ms floor', () async {
      const grace = Duration(seconds: 10);
      final source = _FakeSmoothedRrSource()..seedSmoothed(100)..hasActiveSource = true;
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      final ticks = <TickData>[];
      sut.tickStream.listen(ticks.add);

      sut.start();

      // Metronome should be scheduled at 250 ms (floor), not 100 ms.
      expect(_timerByDelay(const Duration(milliseconds: 250)), isNotNull);

      _fireByDelay(const Duration(milliseconds: 250));
      await Future<void>.delayed(Duration.zero);

      expect(ticks.first.intervalMs, 250);
    });

    test('should clamp the period to the 3000 ms ceiling', () async {
      const grace = Duration(seconds: 10);
      final source = _FakeSmoothedRrSource()..seedSmoothed(5000)..hasActiveSource = true;
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      final ticks = <TickData>[];
      sut.tickStream.listen(ticks.add);

      sut.start();

      expect(_timerByDelay(const Duration(milliseconds: 3000)), isNotNull);

      _fireByDelay(const Duration(milliseconds: 3000));
      await Future<void>.delayed(Duration.zero);

      expect(ticks.first.intervalMs, 3000);
    });

    test('should expose tickStream as a broadcast stream', () async {
      final source = _FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      sut.start();

      final received1 = <int>[];
      final received2 = <int>[];
      sut.tickStream.listen((t) => received1.add(t.intervalMs));
      sut.tickStream.listen((t) => received2.add(t.intervalMs));

      _fireByDelay(const Duration(milliseconds: 1000));
      await Future<void>.delayed(Duration.zero);

      expect(received1, [1000]);
      expect(received2, [1000]);
    });
  });

  // ── Task 8: Genuine heartbeat handling ───────────────────────────────────

  group('HeartRateTickService — genuine heartbeat handling', () {
    const grace = Duration(seconds: 10);

    test('should update the metronome period from a genuine beat without emitting a tick', () async {
      // Cold path: no smoothedIntervalMs at construction.
      final source = _FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      final ticks = <TickData>[];
      sut.tickStream.listen(ticks.add);

      sut.start(); // metronome scheduled at 1000 ms (default period)

      // Emit SMA — updates _currentPeriodMs to 600 but emits no tick.
      source.emitSmoothed(600);
      await Future<void>.delayed(Duration.zero);

      expect(ticks, isEmpty);

      // The original metronome fires at its scheduled 1000 ms delay.
      // It emits using the NOW-current period (600 ms) and reschedules.
      _fireByDelay(const Duration(milliseconds: 1000));
      await Future<void>.delayed(Duration.zero);

      expect(ticks.length, 1);
      expect(ticks.first.intervalMs, 600);
    });

    test('should drop the first replay emission on the warm path and treat the second as genuine', () async {
      // Warm path: subject already has a value (replay on subscribe).
      final source = _FakeSmoothedRrSource()..seedSmoothed(500)..hasActiveSource = true;
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      // After construction the replay of 500 was dropped (warm path).
      // start() schedules the metronome at 500 ms (seeded period).
      sut.start();

      // A genuine emit of 600 updates _currentPeriodMs to 600.
      source.emitSmoothed(600);
      await Future<void>.delayed(Duration.zero);

      // Fire the existing metronome (500 ms delay). It emits at the updated
      // period (600) and reschedules. This confirms the genuine beat was
      // applied and the replay was NOT counted as a period update.
      final ticks = <TickData>[];
      sut.tickStream.listen(ticks.add);
      _fireByDelay(const Duration(milliseconds: 500));
      await Future<void>.delayed(Duration.zero);

      expect(ticks.length, 1);
      expect(ticks.first.intervalMs, 600);
    });

    test('should treat the first emission as genuine on the cold path', () async {
      final source = _FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      sut.start(); // metronome at 1000 ms (default)

      source.emitSmoothed(600);
      await Future<void>.delayed(Duration.zero);

      // First emission on cold path is genuine: activates source and updates period.
      expect(sut.hasActiveSource, isTrue);

      // A grace timer should have been armed.
      expect(_timerByDelay(grace), isNotNull);

      // Fire the original 1000 ms metronome — it should emit at the updated period 600.
      final ticks = <TickData>[];
      sut.tickStream.listen(ticks.add);
      _fireByDelay(const Duration(milliseconds: 1000));
      await Future<void>.delayed(Duration.zero);

      expect(ticks.length, 1);
      expect(ticks.first.intervalMs, 600);
    });

    test('should re-arm the grace timer on each genuine beat', () async {
      final source = _FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      sut.start();

      // First genuine beat.
      source.emitSmoothed(600);
      await Future<void>.delayed(Duration.zero);

      final graceAfterFirst = _timerByDelay(grace);
      expect(graceAfterFirst, isNotNull);

      // Second genuine beat — should cancel old grace and arm a new one.
      source.emitSmoothed(700);
      await Future<void>.delayed(Duration.zero);

      expect(graceAfterFirst!.cancelled, isTrue);

      // A new grace timer with the same duration should now exist and be active.
      final graceTimers = <_FakeTimer>[];
      for (var i = 0; i < timers.length; i++) {
        if (timers[i].delay == grace) graceTimers.add(fakeTimers[i]);
      }
      expect(graceTimers.any((t) => !t.cancelled), isTrue);
    });
  });

  // ── Task 9: Grace window expiry & auto-fallback ───────────────────────────

  group('HeartRateTickService — grace window expiry & auto-fallback', () {
    const grace = Duration(seconds: 10);

    test('should flip hasActiveSource to false when the grace timer fires', () async {
      final source = _FakeSmoothedRrSource()..hasActiveSource = true..seedSmoothed(500);
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      expect(sut.hasActiveSource, isTrue);

      final hasActiveEmissions = <bool>[];
      sut.hasActiveSourceStream.skip(1).listen(hasActiveEmissions.add);

      _fireByDelay(grace);
      await Future<void>.delayed(Duration.zero);

      expect(sut.hasActiveSource, isFalse);
      expect(hasActiveEmissions, [false]);
    });

    test('should keep the metronome running after grace expiry (coasts at last period)', () async {
      final source = _FakeSmoothedRrSource()..hasActiveSource = true..seedSmoothed(500);
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      sut.start();

      // Fire grace — hasActiveSource flips false.
      _fireByDelay(grace);
      await Future<void>.delayed(Duration.zero);
      expect(sut.hasActiveSource, isFalse);

      // Metronome should still fire and emit a tick.
      final ticks = <TickData>[];
      sut.tickStream.listen(ticks.add);

      _fireByDelay(const Duration(milliseconds: 500));
      await Future<void>.delayed(Duration.zero);

      expect(ticks.length, 1);
    });

    test('should flip hasActiveSource back to true when a beat returns after grace expiry', () async {
      final source = _FakeSmoothedRrSource()..hasActiveSource = true..seedSmoothed(500);
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );
      addTearDown(sut.dispose);

      sut.start();

      // Fire grace.
      _fireByDelay(grace);
      await Future<void>.delayed(Duration.zero);
      expect(sut.hasActiveSource, isFalse);

      // A genuine beat arrives.
      source.emitSmoothed(600);
      await Future<void>.delayed(Duration.zero);

      expect(sut.hasActiveSource, isTrue);
    });
  });

  // ── Task 10: ITickService interface ──────────────────────────────────────

  group('HeartRateTickService — ITickService interface', () {
    late _FakeSmoothedRrSource source;
    late HeartRateTickService sut;

    setUp(() {
      source = _FakeSmoothedRrSource();
      sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: const Duration(seconds: 10),
      );
    });

    tearDown(() async {
      sut.dispose();
      await source.close();
    });

    test('should report source as TickSource.heartbeat', () {
      expect(sut.source, TickSource.heartbeat);
    });

    test('should report nominalIntervalMs as 1000', () {
      expect(sut.nominalIntervalMs, 1000);
    });

    test('should expose sourceChanges as an empty stream', () async {
      final received = <TickSource>[];
      sut.sourceChanges.listen(received.add);
      await Future<void>.delayed(Duration.zero);
      expect(received, isEmpty);
    });

    test('should return false from trySwitchTo for any target', () {
      expect(sut.trySwitchTo(TickSource.timer), isFalse);
      expect(sut.trySwitchTo(TickSource.heartbeat), isFalse);
    });
  });

  // ── Task 11: Dispose ──────────────────────────────────────────────────────

  group('HeartRateTickService — dispose', () {
    const grace = Duration(seconds: 10);

    test('should cancel the metronome timer on dispose', () async {
      final source = _FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );

      sut.start();

      final metro = _timerByDelay(const Duration(milliseconds: 1000));
      expect(metro, isNotNull);

      sut.dispose();

      expect(metro!.cancelled, isTrue);
    });

    test('should cancel the grace timer on dispose', () async {
      final source = _FakeSmoothedRrSource()..hasActiveSource = true..seedSmoothed(500);
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );

      final graceTimer = _timerByDelay(grace);
      expect(graceTimer, isNotNull);

      sut.dispose();

      expect(graceTimer!.cancelled, isTrue);
    });

    test('should stop reacting to smoothed emissions after dispose', () async {
      final source = _FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );

      final hadActiveBefore = sut.hasActiveSource;

      sut.dispose();

      // Emit after dispose — should not throw, hasActiveSource unchanged.
      source.emitSmoothed(600);
      await Future<void>.delayed(Duration.zero);

      expect(sut.hasActiveSource, hadActiveBefore);
    });

    test('should close tickStream on dispose (subscribers receive done)', () async {
      final source = _FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );

      bool done = false;
      sut.tickStream.listen((_) {}, onDone: () => done = true);

      sut.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
    });

    test('should close hasActiveSourceStream on dispose (subscribers receive done)', () async {
      final source = _FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );

      bool done = false;
      sut.hasActiveSourceStream.listen((_) {}, onDone: () => done = true);

      sut.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
    });

    test('should not dispose the underlying SmoothedRrSource', () async {
      final source = _FakeSmoothedRrSource();

      final sut = HeartRateTickService(
        smoothedRrSource: source,
        timerFactory: spyFactory,
        graceWindow: grace,
      );

      sut.dispose();

      // The fake source's stream should still be open and usable.
      bool gotData = false;
      final sub = source.smoothedIntervalStream.listen((_) => gotData = true);
      source.emitSmoothed(500);
      await Future<void>.delayed(Duration.zero);

      expect(gotData, isTrue);
      await sub.cancel();
      await source.close();
    });
  });
}
