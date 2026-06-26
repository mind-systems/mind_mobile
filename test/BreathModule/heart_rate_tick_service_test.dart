import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:breath_module/breath_module.dart' show TickData, TickSource;

import 'package:mind/BreathModule/HeartRateTickService.dart';

import 'Fakes/FakeSmoothedRrSource.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

  // ── Construction & seeding ───────────────────────────────────────────────

  group('HeartRateTickService — construction & seeding', () {
    test('should seed the metronome period from currentPeriodMs when available', () {
      final cadence = FakeTickCadenceSource(currentPeriodMs: 600);
      addTearDown(cadence.dispose);

      final sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);
      addTearDown(sut.dispose);

      sut.start();

      // Metronome should be scheduled at the seeded period (600 ms).
      expect(_timerByDelay(const Duration(milliseconds: 600)), isNotNull);
    });

    test('should default the metronome period to 1000 ms when currentPeriodMs is null', () {
      final cadence = FakeTickCadenceSource(currentPeriodMs: null);
      addTearDown(cadence.dispose);

      final sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);
      addTearDown(sut.dispose);

      sut.start();

      expect(_timerByDelay(const Duration(milliseconds: 1000)), isNotNull);
    });
  });

  // ── Metronome lifecycle ───────────────────────────────────────────────────

  group('HeartRateTickService — metronome lifecycle', () {
    test('should not schedule the metronome or emit ticks before start() is called', () async {
      final cadence = FakeTickCadenceSource();
      addTearDown(cadence.dispose);

      final sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);
      addTearDown(sut.dispose);

      final ticks = <TickData>[];
      sut.tickStream.listen(ticks.add);

      cadence.emitPeriod(600);
      await Future<void>.delayed(Duration.zero);

      // No timers should have been scheduled (no start() yet).
      expect(timers, isEmpty);
      expect(ticks, isEmpty);
    });

    test('should emit no immediate/prime tick when start() is called', () async {
      final cadence = FakeTickCadenceSource();
      addTearDown(cadence.dispose);

      final sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);
      addTearDown(sut.dispose);

      final ticks = <TickData>[];
      sut.tickStream.listen(ticks.add);

      sut.start();
      await Future<void>.delayed(Duration.zero);

      expect(ticks, isEmpty);
    });

    test('should emit a tick with the current period when the metronome fires', () async {
      final cadence = FakeTickCadenceSource(currentPeriodMs: 600);
      addTearDown(cadence.dispose);

      final sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);
      addTearDown(sut.dispose);

      final ticks = <TickData>[];
      sut.tickStream.listen(ticks.add);

      sut.start();

      _fireByDelay(const Duration(milliseconds: 600));
      await Future<void>.delayed(Duration.zero);

      expect(ticks.length, 1);
      expect(ticks.first.intervalMs, 600);
    });

    test('should reschedule the metronome after each fire', () async {
      final cadence = FakeTickCadenceSource();
      addTearDown(cadence.dispose);

      final sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);
      addTearDown(sut.dispose);

      sut.start();
      final countBefore = timers.length;

      _fireByDelay(const Duration(milliseconds: 1000));
      await Future<void>.delayed(Duration.zero);

      expect(timers.length, greaterThan(countBefore));
    });

    test('should clamp the period to the 250 ms floor', () async {
      final cadence = FakeTickCadenceSource(currentPeriodMs: 100);
      addTearDown(cadence.dispose);

      final sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);
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
      final cadence = FakeTickCadenceSource(currentPeriodMs: 5000);
      addTearDown(cadence.dispose);

      final sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);
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
      final cadence = FakeTickCadenceSource();
      addTearDown(cadence.dispose);

      final sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);
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

  // ── Cadence period updates ────────────────────────────────────────────────

  group('HeartRateTickService — cadence period updates', () {
    test('should update the metronome period from a cadence emission without emitting a tick', () async {
      // Cold path: no period at construction.
      final cadence = FakeTickCadenceSource(currentPeriodMs: null);
      addTearDown(cadence.dispose);

      final sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);
      addTearDown(sut.dispose);

      final ticks = <TickData>[];
      sut.tickStream.listen(ticks.add);

      sut.start(); // metronome scheduled at 1000 ms (default period)

      // Cadence emits 600 — updates _currentPeriodMs but emits no tick.
      cadence.emitPeriod(600);
      await Future<void>.delayed(Duration.zero);

      expect(ticks, isEmpty);

      // The original metronome fires at its scheduled 1000 ms delay.
      // It emits using the NOW-current period (600 ms) and reschedules.
      _fireByDelay(const Duration(milliseconds: 1000));
      await Future<void>.delayed(Duration.zero);

      expect(ticks.length, 1);
      expect(ticks.first.intervalMs, 600);
    });

    test('should apply cadence-stream period update from the first emission (cold path)', () async {
      final cadence = FakeTickCadenceSource(currentPeriodMs: null);
      addTearDown(cadence.dispose);

      final sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);
      addTearDown(sut.dispose);

      sut.start(); // metronome at 1000 ms (default)

      cadence.emitPeriod(600);
      await Future<void>.delayed(Duration.zero);

      final ticks = <TickData>[];
      sut.tickStream.listen(ticks.add);

      // Fire the original 1000 ms metronome — should emit at the updated period 600.
      _fireByDelay(const Duration(milliseconds: 1000));
      await Future<void>.delayed(Duration.zero);

      expect(ticks.length, 1);
      expect(ticks.first.intervalMs, 600);
    });

    test('should keep the metronome running after cadence source becomes unusable', () async {
      final cadence = FakeTickCadenceSource(currentPeriodMs: 500, initialIsUsable: true);
      addTearDown(cadence.dispose);

      final sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);
      addTearDown(sut.dispose);

      sut.start();

      // Signal that cadence source is no longer usable (grace expired in cadence).
      cadence.setUsable(false);
      await Future<void>.delayed(Duration.zero);

      expect(sut.hasActiveSource, isFalse);

      // Metronome should still fire and emit a tick (coasts at last known period).
      final ticks = <TickData>[];
      sut.tickStream.listen(ticks.add);

      _fireByDelay(const Duration(milliseconds: 500));
      await Future<void>.delayed(Duration.zero);

      expect(ticks.length, 1);
    });
  });

  // ── ITickService interface ────────────────────────────────────────────────

  group('HeartRateTickService — ITickService interface', () {
    late FakeTickCadenceSource cadence;
    late HeartRateTickService sut;

    setUp(() {
      cadence = FakeTickCadenceSource();
      sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);
    });

    tearDown(() {
      sut.dispose();
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

  // ── Dispose ───────────────────────────────────────────────────────────────

  group('HeartRateTickService — dispose', () {
    test('should cancel the metronome timer on dispose', () {
      final cadence = FakeTickCadenceSource();
      final sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);

      sut.start();

      final metro = _timerByDelay(const Duration(milliseconds: 1000));
      expect(metro, isNotNull);

      sut.dispose();

      expect(metro!.cancelled, isTrue);
    });

    test('should stop reacting to cadence period emissions after dispose (no crash)', () async {
      final cadence = FakeTickCadenceSource();
      addTearDown(cadence.dispose);

      final sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);
      sut.start();
      sut.dispose();

      // Emitting after dispose should not throw.
      cadence.emitPeriod(600);
      await Future<void>.delayed(Duration.zero);

      // Metronome was cancelled.
      expect(_timerByDelay(const Duration(milliseconds: 1000))?.cancelled, isTrue);
    });

    test('should close tickStream on dispose (subscribers receive done)', () async {
      final cadence = FakeTickCadenceSource();
      final sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);

      bool done = false;
      sut.tickStream.listen((_) {}, onDone: () => done = true);

      sut.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
    });

    test('should close hasActiveSourceStream on dispose (subscribers receive done)', () async {
      // hasActiveSourceStream delegates to cadence.usableChanges.
      // dispose() calls cadence.dispose() which closes the BehaviorSubject.
      final cadence = FakeTickCadenceSource();
      final sut = HeartRateTickService(cadence: cadence, timerFactory: spyFactory);

      bool done = false;
      sut.hasActiveSourceStream.listen((_) {}, onDone: () => done = true);

      sut.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
    });
  });
}
