import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:mind/BreathModule/TickCadence/RrTickCadenceSource.dart';

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

  const grace = Duration(seconds: 10);

  // ── Construction & seeding ───────────────────────────────────────────────

  group('RrTickCadenceSource — construction & seeding', () {
    test('should seed isUsable true from smoothed source on the warm path', () {
      final source = FakeSmoothedRrSource()
        ..hasActiveSource = true
        ..seedSmoothed(500);
      addTearDown(source.close);

      final sut = RrTickCadenceSource(source, timerFactory: spyFactory, graceWindow: grace);
      addTearDown(sut.dispose);

      expect(sut.isUsable, isTrue);
    });

    test('should seed isUsable false on the cold path', () {
      final source = FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = RrTickCadenceSource(source, timerFactory: spyFactory, graceWindow: grace);
      addTearDown(sut.dispose);

      expect(sut.isUsable, isFalse);
    });

    test('should arm the grace timer at construction on the warm path', () {
      final source = FakeSmoothedRrSource()
        ..hasActiveSource = true
        ..seedSmoothed(500);
      addTearDown(source.close);

      final sut = RrTickCadenceSource(source, timerFactory: spyFactory, graceWindow: grace);
      addTearDown(sut.dispose);

      expect(_timerByDelay(grace), isNotNull);
      expect(_timerByDelay(grace)!.cancelled, isFalse);
    });

    test('should not arm the grace timer at construction on the cold path', () {
      final source = FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = RrTickCadenceSource(source, timerFactory: spyFactory, graceWindow: grace);
      addTearDown(sut.dispose);

      expect(_timerByDelay(grace), isNull);
    });
  });

  // ── Replay guard ─────────────────────────────────────────────────────────

  group('RrTickCadenceSource — replay guard', () {
    test('should drop the first replay on the warm path and not cause a spurious usableChanges transition', () async {
      // Warm path: subject already has a value (replay on subscribe).
      final source = FakeSmoothedRrSource()
        ..hasActiveSource = true
        ..seedSmoothed(500);
      addTearDown(source.close);

      final sut = RrTickCadenceSource(source, timerFactory: spyFactory, graceWindow: grace);
      addTearDown(sut.dispose);

      // isUsable is seeded true; grace is armed. The replay of 500 was dropped.
      expect(sut.isUsable, isTrue);

      // Track transitions after the seeded value.
      final transitions = <bool>[];
      sut.usableChanges.skip(1).listen(transitions.add);

      // A genuine beat arrives — should NOT produce a false→true flip
      // because isUsable is already true.
      source.emitSmoothed(600);
      await Future<void>.delayed(Duration.zero);

      expect(transitions, isEmpty);
      expect(sut.isUsable, isTrue);
    });

    test('should treat the first emission as genuine on the cold path and set isUsable true', () async {
      final source = FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = RrTickCadenceSource(source, timerFactory: spyFactory, graceWindow: grace);
      addTearDown(sut.dispose);

      expect(sut.isUsable, isFalse);

      source.emitSmoothed(600);
      await Future<void>.delayed(Duration.zero);

      expect(sut.isUsable, isTrue);
    });
  });

  // ── Grace window ─────────────────────────────────────────────────────────

  group('RrTickCadenceSource — grace window', () {
    test('should re-arm the grace timer on each genuine beat', () async {
      final source = FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = RrTickCadenceSource(source, timerFactory: spyFactory, graceWindow: grace);
      addTearDown(sut.dispose);

      // First genuine beat.
      source.emitSmoothed(600);
      await Future<void>.delayed(Duration.zero);

      final graceAfterFirst = _timerByDelay(grace);
      expect(graceAfterFirst, isNotNull);

      // Second genuine beat — should cancel old grace and arm a new one.
      source.emitSmoothed(700);
      await Future<void>.delayed(Duration.zero);

      expect(graceAfterFirst!.cancelled, isTrue);

      final graceTimers = <_FakeTimer>[];
      for (var i = 0; i < timers.length; i++) {
        if (timers[i].delay == grace) graceTimers.add(fakeTimers[i]);
      }
      expect(graceTimers.any((t) => !t.cancelled), isTrue);
    });

    test('should flip isUsable to false when the grace timer fires', () async {
      final source = FakeSmoothedRrSource()
        ..hasActiveSource = true
        ..seedSmoothed(500);
      addTearDown(source.close);

      final sut = RrTickCadenceSource(source, timerFactory: spyFactory, graceWindow: grace);
      addTearDown(sut.dispose);

      expect(sut.isUsable, isTrue);

      final transitions = <bool>[];
      sut.usableChanges.skip(1).listen(transitions.add);

      _fireByDelay(grace);
      await Future<void>.delayed(Duration.zero);

      expect(sut.isUsable, isFalse);
      expect(transitions, [false]);
    });

    test('should flip isUsable back to true when a beat returns after grace expiry', () async {
      final source = FakeSmoothedRrSource()
        ..hasActiveSource = true
        ..seedSmoothed(500);
      addTearDown(source.close);

      final sut = RrTickCadenceSource(source, timerFactory: spyFactory, graceWindow: grace);
      addTearDown(sut.dispose);

      // Fire grace — isUsable flips false.
      _fireByDelay(grace);
      await Future<void>.delayed(Duration.zero);
      expect(sut.isUsable, isFalse);

      // A genuine beat returns.
      source.emitSmoothed(600);
      await Future<void>.delayed(Duration.zero);

      expect(sut.isUsable, isTrue);
    });
  });

  // ── Dispose ───────────────────────────────────────────────────────────────

  group('RrTickCadenceSource — dispose', () {
    test('should cancel the grace timer on dispose', () async {
      final source = FakeSmoothedRrSource()
        ..hasActiveSource = true
        ..seedSmoothed(500);
      addTearDown(source.close);

      final sut = RrTickCadenceSource(source, timerFactory: spyFactory, graceWindow: grace);

      final graceTimer = _timerByDelay(grace);
      expect(graceTimer, isNotNull);

      sut.dispose();

      expect(graceTimer!.cancelled, isTrue);
    });

    test('should stop reacting to smoothed emissions after dispose', () async {
      final source = FakeSmoothedRrSource();
      addTearDown(source.close);

      final sut = RrTickCadenceSource(source, timerFactory: spyFactory, graceWindow: grace);

      expect(sut.isUsable, isFalse);

      sut.dispose();

      // Emit after dispose — should not throw or change the last-known state.
      source.emitSmoothed(600);
      await Future<void>.delayed(Duration.zero);

      // isUsable reads the last value of the closed BehaviorSubject.
      expect(sut.isUsable, isFalse);
    });

    test('should not dispose the underlying SmoothedRrSource', () async {
      final source = FakeSmoothedRrSource();

      final sut = RrTickCadenceSource(source, timerFactory: spyFactory, graceWindow: grace);
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
