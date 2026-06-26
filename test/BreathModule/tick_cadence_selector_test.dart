import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:breath_module/breath_module.dart' show TickData;

import 'package:mind/BreathModule/TickCadence/TickCadenceSelector.dart';
import 'package:mind/BreathModule/TickCadence/RrTickCadenceSource.dart';
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
  // Spy timer factory — shared across selector unit tests and the integration test.
  late List<({Duration delay, void Function() cb})> timers;
  late List<_FakeTimer> fakeTimers;

  Timer spyFactory(Duration d, void Function() cb) {
    final t = _FakeTimer();
    timers.add((delay: d, cb: cb));
    fakeTimers.add(t);
    return t;
  }

  void fireByDelay(Duration d) {
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

  // ── Construction ──────────────────────────────────────────────────────────

  group('TickCadenceSelector — construction', () {
    test('isUsable is true when any source is usable at construction', () {
      final cadence = FakeTickCadenceSource(initialIsUsable: true);
      final selector = TickCadenceSelector([cadence]);
      addTearDown(selector.dispose);

      expect(selector.isUsable, isTrue);
    });

    test('isUsable is false when no source is usable at construction', () {
      final cadence = FakeTickCadenceSource(initialIsUsable: false);
      final selector = TickCadenceSelector([cadence]);
      addTearDown(selector.dispose);

      expect(selector.isUsable, isFalse);
    });

    test('currentPeriodMs returns null when no source has a period', () {
      final cadence = FakeTickCadenceSource(currentPeriodMs: null);
      final selector = TickCadenceSelector([cadence]);
      addTearDown(selector.dispose);

      expect(selector.currentPeriodMs, isNull);
    });

    test('currentPeriodMs falls back to sources.first snapshot even when no source is usable', () {
      final cadence = FakeTickCadenceSource(currentPeriodMs: 800, initialIsUsable: false);
      final selector = TickCadenceSelector([cadence]);
      addTearDown(selector.dispose);

      // _activeSource is null (not usable) → fallback to sources.first
      expect(selector.currentPeriodMs, 800);
    });

    test('currentPeriodMs returns active source snapshot after async resolution', () async {
      final cadence = FakeTickCadenceSource(currentPeriodMs: 600, initialIsUsable: true);
      final selector = TickCadenceSelector([cadence]);
      addTearDown(selector.dispose);

      await Future<void>.delayed(Duration.zero); // let _reSelect wire _activeSource

      expect(selector.currentPeriodMs, 600);
    });
  });

  // ── smoothedPeriodMs forwarding ───────────────────────────────────────────

  group('TickCadenceSelector — smoothedPeriodMs forwarding', () {
    test('forwards periods from source once it becomes usable', () async {
      final cadence = FakeTickCadenceSource(initialIsUsable: false);
      final selector = TickCadenceSelector([cadence]);
      addTearDown(selector.dispose);

      final periods = <int>[];
      selector.smoothedPeriodMs.listen(periods.add);

      // Source becomes usable — selector should subscribe its pipe.
      cadence.setUsable(true);
      await Future<void>.delayed(Duration.zero);

      // Now a period emission should be forwarded.
      cadence.emitPeriod(700);
      await Future<void>.delayed(Duration.zero);

      expect(periods, [700]);
    });

    test('stops forwarding periods when source becomes unusable', () async {
      final cadence = FakeTickCadenceSource(initialIsUsable: true);
      final selector = TickCadenceSelector([cadence]);
      addTearDown(selector.dispose);

      await Future<void>.delayed(Duration.zero); // let _reSelect wire pipe

      final periods = <int>[];
      selector.smoothedPeriodMs.listen(periods.add);

      // Source loses usability — selector should cancel the pipe.
      cadence.setUsable(false);
      await Future<void>.delayed(Duration.zero);

      // Further emissions should NOT be forwarded.
      cadence.emitPeriod(700);
      await Future<void>.delayed(Duration.zero);

      expect(periods, isEmpty);
    });

    test('pass-through: period from a single usable source reaches the output', () async {
      final cadence = FakeTickCadenceSource(initialIsUsable: true);
      final selector = TickCadenceSelector([cadence]);
      addTearDown(selector.dispose);

      await Future<void>.delayed(Duration.zero); // let pipe subscribe

      final periods = <int>[];
      selector.smoothedPeriodMs.listen(periods.add);

      cadence.emitPeriod(550);
      await Future<void>.delayed(Duration.zero);

      expect(periods, [550]);
    });
  });

  // ── usableChanges ─────────────────────────────────────────────────────────

  group('TickCadenceSelector — usableChanges', () {
    test('emits true when a source becomes usable', () async {
      final cadence = FakeTickCadenceSource(initialIsUsable: false);
      final selector = TickCadenceSelector([cadence]);
      addTearDown(selector.dispose);

      final transitions = <bool>[];
      selector.usableChanges.skip(1).listen(transitions.add); // skip seeded false

      cadence.setUsable(true);
      await Future<void>.delayed(Duration.zero);

      expect(transitions, [true]);
      expect(selector.isUsable, isTrue);
    });

    test('emits false when the last usable source becomes unusable', () async {
      final cadence = FakeTickCadenceSource(initialIsUsable: true);
      final selector = TickCadenceSelector([cadence]);
      addTearDown(selector.dispose);

      final transitions = <bool>[];
      selector.usableChanges.skip(1).listen(transitions.add); // skip seeded true

      cadence.setUsable(false);
      await Future<void>.delayed(Duration.zero);

      expect(transitions, [false]);
      expect(selector.isUsable, isFalse);
    });
  });

  // ── Dispose ───────────────────────────────────────────────────────────────

  group('TickCadenceSelector — dispose', () {
    test('calls dispose on all child sources', () {
      final cadence = FakeTickCadenceSource();
      final selector = TickCadenceSelector([cadence]);

      selector.dispose();

      expect(cadence.disposed, isTrue);
    });

    test('closes usableChanges (subscribers receive done) on dispose', () async {
      final cadence = FakeTickCadenceSource();
      final selector = TickCadenceSelector([cadence]);

      bool done = false;
      selector.usableChanges.listen((_) {}, onDone: () => done = true);

      selector.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
    });

    test('closes smoothedPeriodMs (subscribers receive done) on dispose', () async {
      final cadence = FakeTickCadenceSource();
      final selector = TickCadenceSelector([cadence]);

      bool done = false;
      selector.smoothedPeriodMs.listen((_) {}, onDone: () => done = true);

      selector.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
    });
  });

  // ── Integration: cold-path first beat ────────────────────────────────────
  //
  // Verifies the behavior-preservation linchpin documented in the plan:
  // a cold-path first genuine beat must propagate through the full chain
  //   FakeSmoothedRrSource → RrTickCadenceSource → TickCadenceSelector → HeartRateTickService
  // and update the metronome period before its next fire.

  group('TickCadenceSelector — integration', () {
    const grace = Duration(seconds: 10);

    test('cold-path first beat updates metronome period via full cadence chain', () async {
      // Cold path: no smoothed period, no active source.
      final source = FakeSmoothedRrSource();
      addTearDown(source.close);

      final rrCadence = RrTickCadenceSource(source,
          timerFactory: spyFactory, graceWindow: grace);
      final selector = TickCadenceSelector([rrCadence]);
      final heart =
          HeartRateTickService(cadence: selector, timerFactory: spyFactory);
      // heart.dispose() chains → selector.dispose() → rrCadence.dispose()
      addTearDown(heart.dispose);

      heart.start(); // schedules metronome at 1000 ms (default, cold path)

      // Emit a genuine beat — triggers the full async chain:
      // 1. rrCadence._onSmoothed(600) → isUsable flips true (grace armed)
      // 2. selector._reSelect() (microtask) → pipes to rrCadence.smoothedPeriodMs
      // 3. BehaviorSubject replays 600 → _periodController.add(600)
      // 4. heart._cadenceSub (microtask) → _currentPeriodMs = 600
      source.emitSmoothed(600);
      await Future<void>.delayed(Duration.zero);

      // The metronome was still scheduled at the original 1000 ms delay.
      // Firing it now should emit TickData(600) — the updated period.
      final ticks = <TickData>[];
      heart.tickStream.listen(ticks.add);

      fireByDelay(const Duration(milliseconds: 1000));
      await Future<void>.delayed(Duration.zero);

      expect(ticks.length, 1);
      expect(ticks.first.intervalMs, 600);
    });

    test('warm-path construction seeds the metronome period before any async event', () async {
      // Warm path: smoothed period already available, source active.
      final source = FakeSmoothedRrSource()
        ..hasActiveSource = true
        ..seedSmoothed(500);
      addTearDown(source.close);

      final rrCadence = RrTickCadenceSource(source,
          timerFactory: spyFactory, graceWindow: grace);
      final selector = TickCadenceSelector([rrCadence]);
      final heart =
          HeartRateTickService(cadence: selector, timerFactory: spyFactory);
      addTearDown(heart.dispose);

      // _currentPeriodMs is seeded synchronously via currentPeriodMs getter (500).
      // No await needed before start().
      heart.start(); // schedules metronome at 500 ms

      final ticks = <TickData>[];
      heart.tickStream.listen(ticks.add);

      fireByDelay(const Duration(milliseconds: 500));
      await Future<void>.delayed(Duration.zero);

      expect(ticks.length, 1);
      expect(ticks.first.intervalMs, 500);
    });
  });
}
