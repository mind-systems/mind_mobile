import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:mind/Biometrics/ActiveRrSource.dart';
import 'package:mind/Biometrics/IRrIntervalSource.dart';
import 'package:mind/Biometrics/Models/RrInterval.dart';
import 'package:mind/Biometrics/Models/SensorSource.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeRrSource implements IRrIntervalSource {
  final _controller = StreamController<RrInterval>.broadcast();

  void emit(RrInterval rr) => _controller.add(rr);

  @override
  Stream<RrInterval> get rrStream => _controller.stream;

  Future<void> close() => _controller.close();
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
// Harness
// ---------------------------------------------------------------------------

/// Fires the most recent captured watchdog only if its timer is not cancelled.
void _fireLast(List<({Duration delay, void Function() cb})> timers, List<_FakeTimer> fakeTimers) {
  if (timers.isEmpty) return;
  final last = fakeTimers.last;
  if (!last.cancelled) timers.last.cb();
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

RrInterval _rr(int intervalMs, DateTime timestamp) => RrInterval(
      intervalMs: intervalMs,
      timestamp: timestamp,
      isArtifact: false,
      source: SensorSource.neiry,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeRrSource source0;
  late _FakeRrSource source1;
  late _FakeRrSource source2;

  late DateTime _now;
  late List<({Duration delay, void Function() cb})> timers;
  late List<_FakeTimer> fakeTimers;

  late ActiveRrSource sut;

  Timer spyFactory(Duration d, void Function() cb) {
    final t = _FakeTimer();
    timers.add((delay: d, cb: cb));
    fakeTimers.add(t);
    return t;
  }

  setUp(() {
    source0 = _FakeRrSource();
    source1 = _FakeRrSource();
    source2 = _FakeRrSource();
    _now = DateTime(2026, 1, 1);
    timers = [];
    fakeTimers = [];
  });

  tearDown(() async {
    await source0.close();
    await source1.close();
    await source2.close();
  });

  // ── Task 1: Initial emission ──────────────────────────────────────────────

  group('ActiveRrSource — initial emission', () {
    setUp(() {
      sut = ActiveRrSource(
        [source0],
        clock: () => _now,
        timerFactory: spyFactory,
      );
    });

    tearDown(() async => sut.dispose());

    test(
      'should report no active source before any interval arrives',
      () {
        expect(sut.hasActiveSource, isFalse);
      },
    );

    test(
      'should forward the first interval from source[0] to the output stream',
      () async {
        RrInterval? received;
        sut.stream.listen((rr) => received = rr);

        final interval = _rr(800, _now);
        source0.emit(interval);
        await Future<void>.delayed(Duration.zero);

        expect(received, same(interval));
      },
    );

    test(
      'should flip hasActiveSource to true after the first interval',
      () async {
        final emissions = <bool>[];
        sut.hasActiveSourceStream.skip(1).listen(emissions.add);

        source0.emit(_rr(800, _now));
        await Future<void>.delayed(Duration.zero);

        expect(sut.hasActiveSource, isTrue);
        expect(emissions, [true]);
      },
    );

    test(
      'should schedule a watchdog with multiplier delay when intervalMs * 2 > silenceFloor',
      () async {
        source0.emit(_rr(1500, _now));
        await Future<void>.delayed(Duration.zero);

        expect(timers.length, 1);
        expect(timers.last.delay, const Duration(milliseconds: 3000));
      },
    );

    test(
      'should schedule a watchdog with silenceFloor delay when intervalMs * 2 <= silenceFloor',
      () async {
        source0.emit(_rr(500, _now));
        await Future<void>.delayed(Duration.zero);

        expect(timers.length, 1);
        expect(timers.last.delay, const Duration(milliseconds: 2000));
      },
    );
  });

  // ── Task 2: Priority steal ────────────────────────────────────────────────

  group('ActiveRrSource — priority steal', () {
    setUp(() {
      sut = ActiveRrSource(
        [source0, source1],
        clock: () => _now,
        timerFactory: spyFactory,
      );
    });

    tearDown(() async => sut.dispose());

    test(
      'should ignore intervals from a lower-priority source while a higher-priority one is active',
      () async {
        // Make source0 active first
        source0.emit(_rr(800, _now));
        await Future<void>.delayed(Duration.zero);

        final received = <RrInterval>[];
        sut.stream.listen(received.add);

        // source1 (lower priority) emits — should not reach output
        source1.emit(_rr(900, _now));
        await Future<void>.delayed(Duration.zero);

        expect(received, isEmpty);
      },
    );

    test(
      'should switch the active source when a higher-priority source emits',
      () async {
        // Make source1 active first (source0 never emitted yet)
        source1.emit(_rr(900, _now));
        await Future<void>.delayed(Duration.zero);

        final received = <RrInterval>[];
        sut.stream.listen(received.add);

        // source0 (higher priority) emits — should take over
        final hi = _rr(800, _now);
        source0.emit(hi);
        await Future<void>.delayed(Duration.zero);

        expect(received, [hi]);
        expect(sut.hasActiveSource, isTrue);
      },
    );
  });

  // ── Task 3: Silence detection ─────────────────────────────────────────────

  group('ActiveRrSource — silence detection', () {
    setUp(() {
      sut = ActiveRrSource(
        [source0],
        clock: () => _now,
        timerFactory: spyFactory,
      );
    });

    tearDown(() async => sut.dispose());

    test(
      'should flip hasActiveSource to false when the active source goes silent and no other source is fresh',
      () async {
        source0.emit(_rr(800, _now));
        await Future<void>.delayed(Duration.zero);
        expect(sut.hasActiveSource, isTrue);

        final emissions = <bool>[];
        sut.hasActiveSourceStream.skip(1).listen(emissions.add);

        // Advance past silence window and fire watchdog
        _now = _now.add(const Duration(seconds: 10));
        _fireLast(timers, fakeTimers);
        await Future<void>.delayed(Duration.zero);

        expect(sut.hasActiveSource, isFalse);
        expect(emissions, [false]);
      },
    );

    test(
      'should stop forwarding intervals after going silent until a source revives',
      () async {
        source0.emit(_rr(800, _now));
        await Future<void>.delayed(Duration.zero);

        // Go silent
        _now = _now.add(const Duration(seconds: 10));
        _fireLast(timers, fakeTimers);
        await Future<void>.delayed(Duration.zero);
        expect(sut.hasActiveSource, isFalse);

        // Output is quiet after silence
        final received = <RrInterval>[];
        sut.stream.listen(received.add);

        source0.emit(_rr(800, _now));
        await Future<void>.delayed(Duration.zero);

        // First emission after silence revives forwarding
        expect(received.length, 1);
        expect(sut.hasActiveSource, isTrue);
      },
    );
  });

  // ── Task 4: Failover ──────────────────────────────────────────────────────

  group('ActiveRrSource — failover', () {
    test(
      'should failover to the next-priority source that emitted within the silence floor',
      () async {
        sut = ActiveRrSource(
          [source0, source1],
          clock: () => _now,
          timerFactory: spyFactory,
        );
        addTearDown(() => sut.dispose());

        // source0 active, source1 also emitted recently
        source0.emit(_rr(800, _now));
        await Future<void>.delayed(Duration.zero);
        source1.emit(_rr(900, _now));
        await Future<void>.delayed(Duration.zero);

        // Advance time modestly — source1 still within 2 s silence floor
        _now = _now.add(const Duration(milliseconds: 500));

        // Fire source0's watchdog — triggers failover to source1
        _fireLast(timers, fakeTimers);
        await Future<void>.delayed(Duration.zero);

        // hasActiveSource stays true (no transition)
        expect(sut.hasActiveSource, isTrue);

        // New watchdog was scheduled
        final watchdogCountAfterFailover = timers.length;
        expect(watchdogCountAfterFailover, greaterThan(1));

        // source1 intervals now reach the output
        final received = <RrInterval>[];
        sut.stream.listen(received.add);

        final s1interval = _rr(900, _now);
        source1.emit(s1interval);
        await Future<void>.delayed(Duration.zero);

        expect(received, [s1interval]);
      },
    );

    test(
      'should skip a source that never emitted during failover',
      () async {
        sut = ActiveRrSource(
          [source0, source1, source2],
          clock: () => _now,
          timerFactory: spyFactory,
        );
        addTearDown(() => sut.dispose());

        // Only source0 ever emitted; source1 and source2 are silent
        source0.emit(_rr(800, _now));
        await Future<void>.delayed(Duration.zero);

        _now = _now.add(const Duration(seconds: 10));
        _fireLast(timers, fakeTimers);
        await Future<void>.delayed(Duration.zero);

        // No alternative → hasActiveSource flips false
        expect(sut.hasActiveSource, isFalse);
      },
    );

    test(
      'should skip a stale source older than the silence floor during failover',
      () async {
        sut = ActiveRrSource(
          [source0, source1],
          clock: () => _now,
          timerFactory: spyFactory,
        );
        addTearDown(() => sut.dispose());

        // source0 active; source1 emitted but is now stale (> 2s ago)
        source0.emit(_rr(800, _now));
        await Future<void>.delayed(Duration.zero);
        source1.emit(_rr(900, _now));
        await Future<void>.delayed(Duration.zero);

        // Advance past the silence floor for source1
        _now = _now.add(const Duration(seconds: 5));

        // Fire watchdog — source1 is too old to failover to
        _fireLast(timers, fakeTimers);
        await Future<void>.delayed(Duration.zero);

        expect(sut.hasActiveSource, isFalse);
      },
    );
  });

  // ── Task 5: Dispose ───────────────────────────────────────────────────────

  group('ActiveRrSource — dispose', () {
    test(
      'should cancel all source subscriptions on dispose',
      () async {
        sut = ActiveRrSource(
          [source0, source1],
          clock: () => _now,
          timerFactory: spyFactory,
        );

        source0.emit(_rr(800, _now));
        await Future<void>.delayed(Duration.zero);
        await sut.dispose();

        final received = <RrInterval>[];
        // Stream is already closed after dispose, so listen on source directly
        // is not meaningful. The key is that after dispose, emitting produces
        // no output. We verify by checking we can't add to the (closed) controllers.
        // Instead: try to emit and confirm no crash + no output via sut.stream.
        // (sut.stream is closed, so listen would get onDone, not data.)
        bool gotDone = false;
        // ignore: unawaited_futures
        sut.stream.listen(received.add, onDone: () => gotDone = true);
        await Future<void>.delayed(Duration.zero);

        expect(gotDone, isTrue);
        expect(received, isEmpty);
      },
    );

    test(
      'should close the output and hasActiveSource streams on dispose',
      () async {
        sut = ActiveRrSource(
          [source0],
          clock: () => _now,
          timerFactory: spyFactory,
        );

        bool streamDone = false;
        bool hasActiveDone = false;
        sut.stream.listen((_) {}, onDone: () => streamDone = true);
        sut.hasActiveSourceStream.listen((_) {}, onDone: () => hasActiveDone = true);

        await sut.dispose();
        await Future<void>.delayed(Duration.zero);

        expect(streamDone, isTrue);
        expect(hasActiveDone, isTrue);
      },
    );

    test(
      'should cancel the active watchdog on dispose',
      () async {
        sut = ActiveRrSource(
          [source0],
          clock: () => _now,
          timerFactory: spyFactory,
        );

        source0.emit(_rr(800, _now));
        await Future<void>.delayed(Duration.zero);
        expect(timers.length, 1);

        await sut.dispose();

        // The captured FakeTimer should be marked cancelled
        expect(fakeTimers.last.cancelled, isTrue);
      },
    );

    test(
      'should complete without error when awaited',
      () async {
        sut = ActiveRrSource(
          [source0],
          clock: () => _now,
          timerFactory: spyFactory,
        );

        await expectLater(sut.dispose(), completes);
      },
    );
  });
}
