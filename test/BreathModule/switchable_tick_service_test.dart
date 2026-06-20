import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:breath_module/breath_module.dart' show TickData, TickSource;

import 'package:mind/BreathModule/SwitchableTickService.dart';
import 'package:mind/BreathModule/ClockTickService.dart';
import 'package:mind/BreathModule/HeartRateTickService.dart';

// ---------------------------------------------------------------------------
// Fakes
//
// Both fakes use Dart's implicit-interface feature (implements on concrete class)
// so they type-check against SwitchableTickService's constructor which demands
// ClockTickService / HeartRateTickService, not the ITickService interface.
// ---------------------------------------------------------------------------

class _FakeClockTickService implements ClockTickService {
  final _controller = StreamController<TickData>.broadcast();
  bool disposed = false;

  /// Push a tick into the fake's stream; the SUT forwards it when clock is active.
  void emit(TickData tick) => _controller.add(tick);

  @override
  Stream<TickData> get tickStream => _controller.stream;

  @override
  TickSource get source => TickSource.timer;

  @override
  int get nominalIntervalMs => 1000;

  @override
  Stream<TickSource> get sourceChanges => const Stream.empty();

  @override
  bool trySwitchTo(TickSource target) => false;

  @override
  void simulateTick() {}

  @override
  void dispose() {
    disposed = true;
    _controller.close();
  }
}

class _FakeHeartRateTickService implements HeartRateTickService {
  final _controller = StreamController<TickData>.broadcast();
  final _hasActiveController = StreamController<bool>.broadcast();
  bool disposed = false;

  /// Mutable — set to true before calling trySwitchTo(heartbeat) to allow the switch.
  @override
  bool hasActiveSource = false;

  /// Push a tick into the fake's stream; the SUT forwards it when heart is active.
  void emit(TickData tick) => _controller.add(tick);

  /// Emit on the hasActiveSourceStream — triggers SUT's auto-fallback listener.
  void emitHasActiveSource(bool value) => _hasActiveController.add(value);

  /// Close the hasActiveSourceStream controller (call from tearDown).
  /// Not called by dispose() — mirrors the real implementation which does not
  /// own ActiveRrSource and therefore does not close its stream.
  void closeActiveSourceController() {
    if (!_hasActiveController.isClosed) _hasActiveController.close();
  }

  @override
  Stream<TickData> get tickStream => _controller.stream;

  @override
  TickSource get source => TickSource.heartbeat;

  @override
  int get nominalIntervalMs => 1000;

  @override
  Stream<bool> get hasActiveSourceStream => _hasActiveController.stream;

  @override
  Stream<TickSource> get sourceChanges => const Stream.empty();

  @override
  bool trySwitchTo(TickSource target) => false;

  @override
  void start() {}

  @override
  void dispose() {
    disposed = true;
    _controller.close();
    // hasActiveController intentionally NOT closed here — ownership mirrors
    // the real HeartRateTickService which does not dispose ActiveRrSource.
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Shared fixtures for tasks 6–8. Each test gets fresh instances via setUp.
  late _FakeClockTickService clock;
  late _FakeHeartRateTickService heart;
  late SwitchableTickService sut;

  setUp(() {
    clock = _FakeClockTickService();
    heart = _FakeHeartRateTickService();
    sut = SwitchableTickService(clock: clock, heart: heart);
    addTearDown(() {
      // Guard against double-dispose: clock.disposed is set by sut.dispose().
      if (!clock.disposed) sut.dispose();
      // Always close the hasActiveController — not owned by dispose().
      heart.closeActiveSourceController();
    });
  });

  // ── Task 6: Construction and initial source ───────────────────────────────

  group('SwitchableTickService — construction and initial source', () {
    test('should expose source as TickSource.timer when constructed', () {
      expect(sut.source, TickSource.timer);
    });

    test(
      'should forward clock ticks through tickStream when constructed (initial active source is clock)',
      () async {
        TickData? received;
        sut.tickStream.listen((t) => received = t);

        clock.emit(TickData(1000));
        await Future<void>.delayed(Duration.zero);

        expect(received?.intervalMs, 1000);
      },
    );

    test(
      'should not forward heart ticks through tickStream when active source is timer',
      () async {
        TickData? received;
        sut.tickStream.listen((t) => received = t);

        heart.emit(TickData(850));
        await Future<void>.delayed(Duration.zero);

        expect(received, isNull);
      },
    );

    test(
      'should expose tickStream as a broadcast stream supporting multiple independent subscribers',
      () async {
        final received1 = <int>[];
        final received2 = <int>[];
        sut.tickStream.listen((t) => received1.add(t.intervalMs));
        sut.tickStream.listen((t) => received2.add(t.intervalMs));

        clock.emit(TickData(500));
        await Future<void>.delayed(Duration.zero);

        expect(received1, [500]);
        expect(received2, [500]);
      },
    );
  });

  // ── Task 7: trySwitchTo ───────────────────────────────────────────────────

  group('SwitchableTickService — trySwitchTo', () {
    test(
      'should return true and forward heart ticks (stop forwarding clock ticks) when switching to heartbeat and heart.hasActiveSource is true',
      () async {
        heart.hasActiveSource = true;
        final result = sut.trySwitchTo(TickSource.heartbeat);
        expect(result, isTrue);
        expect(sut.source, TickSource.heartbeat);

        final received = <int>[];
        sut.tickStream.listen((t) => received.add(t.intervalMs));

        heart.emit(TickData(900));
        await Future<void>.delayed(Duration.zero);
        expect(received, [900]);

        received.clear();
        clock.emit(TickData(1000));
        await Future<void>.delayed(Duration.zero);
        expect(received, isEmpty);
      },
    );

    test(
      'should return false and leave source unchanged when switching to heartbeat and heart.hasActiveSource is false',
      () {
        heart.hasActiveSource = false;
        final result = sut.trySwitchTo(TickSource.heartbeat);
        expect(result, isFalse);
        expect(sut.source, TickSource.timer);
      },
    );

    test(
      'should return true and forward clock ticks again when switching back to timer from heartbeat',
      () async {
        heart.hasActiveSource = true;
        sut.trySwitchTo(TickSource.heartbeat);

        final result = sut.trySwitchTo(TickSource.timer);
        expect(result, isTrue);
        expect(sut.source, TickSource.timer);

        final received = <int>[];
        sut.tickStream.listen((t) => received.add(t.intervalMs));

        clock.emit(TickData(1000));
        await Future<void>.delayed(Duration.zero);
        expect(received, [1000]);

        received.clear();
        heart.emit(TickData(900));
        await Future<void>.delayed(Duration.zero);
        expect(received, isEmpty);
      },
    );

    test(
      'should return true and emit nothing on sourceChanges when target equals the already-active source',
      () async {
        final changes = <TickSource>[];
        sut.sourceChanges.listen((s) => changes.add(s));

        // Already on timer — switching to timer again should be a no-op.
        final result = sut.trySwitchTo(TickSource.timer);
        await Future<void>.delayed(Duration.zero);

        expect(result, isTrue);
        expect(changes, isEmpty);
      },
    );

    test(
      'should emit the new source on sourceChanges only when an actual switch occurs',
      () async {
        final changes = <TickSource>[];
        sut.sourceChanges.listen((s) => changes.add(s));

        heart.hasActiveSource = true;
        sut.trySwitchTo(TickSource.heartbeat);
        await Future<void>.delayed(Duration.zero);

        expect(changes, [TickSource.heartbeat]);
      },
    );
  });

  // ── Task 8: Auto-fallback on source-lost event ───────────────────────────

  group('SwitchableTickService — auto-fallback on source-lost event', () {
    test(
      'should revert source to TickSource.timer when active is heartbeat and hasActiveSourceStream emits false',
      () async {
        heart.hasActiveSource = true;
        sut.trySwitchTo(TickSource.heartbeat);
        expect(sut.source, TickSource.heartbeat);

        heart.emitHasActiveSource(false);
        await Future<void>.delayed(Duration.zero);

        expect(sut.source, TickSource.timer);
      },
    );

    test(
      'should emit TickSource.timer on sourceChanges when auto-fallback triggers',
      () async {
        final changes = <TickSource>[];
        sut.sourceChanges.listen((s) => changes.add(s));

        heart.hasActiveSource = true;
        sut.trySwitchTo(TickSource.heartbeat);
        await Future<void>.delayed(Duration.zero);

        heart.emitHasActiveSource(false);
        await Future<void>.delayed(Duration.zero);

        expect(changes, [TickSource.heartbeat, TickSource.timer]);
      },
    );

    test(
      'should forward clock ticks (not heart ticks) after auto-fallback',
      () async {
        heart.hasActiveSource = true;
        sut.trySwitchTo(TickSource.heartbeat);

        heart.emitHasActiveSource(false);
        await Future<void>.delayed(Duration.zero);

        final received = <int>[];
        sut.tickStream.listen((t) => received.add(t.intervalMs));

        clock.emit(TickData(1000));
        await Future<void>.delayed(Duration.zero);
        expect(received, [1000]);

        received.clear();
        heart.emit(TickData(900));
        await Future<void>.delayed(Duration.zero);
        expect(received, isEmpty);
      },
    );

    test(
      'should not switch or emit when active is timer and hasActiveSourceStream emits false',
      () async {
        final changes = <TickSource>[];
        sut.sourceChanges.listen((s) => changes.add(s));

        // Source is timer (initial). Emit false — condition guards on heartbeat-active only.
        heart.emitHasActiveSource(false);
        await Future<void>.delayed(Duration.zero);

        expect(sut.source, TickSource.timer);
        expect(changes, isEmpty);
      },
    );
  });

  // ── Task 9: Dispose propagation and cleanup ───────────────────────────────
  //
  // Each test creates its own instances to control exactly when dispose is called.
  // Instances from the outer setUp are cleaned up by the outer tearDown as usual.

  group('SwitchableTickService — dispose', () {
    test('should call dispose on the clock delegate when disposed', () {
      final localClock = _FakeClockTickService();
      final localHeart = _FakeHeartRateTickService();
      addTearDown(localHeart.closeActiveSourceController);
      final localSut = SwitchableTickService(clock: localClock, heart: localHeart);

      localSut.dispose();

      expect(localClock.disposed, isTrue);
    });

    test('should call dispose on the heart delegate when disposed', () {
      final localClock = _FakeClockTickService();
      final localHeart = _FakeHeartRateTickService();
      addTearDown(localHeart.closeActiveSourceController);
      final localSut = SwitchableTickService(clock: localClock, heart: localHeart);

      localSut.dispose();

      expect(localHeart.disposed, isTrue);
    });

    test('should close tickStream (subscribers receive done) when disposed', () async {
      final localClock = _FakeClockTickService();
      final localHeart = _FakeHeartRateTickService();
      addTearDown(localHeart.closeActiveSourceController);
      final localSut = SwitchableTickService(clock: localClock, heart: localHeart);

      bool done = false;
      localSut.tickStream.listen((_) {}, onDone: () => done = true);

      localSut.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
    });

    test('should close sourceChanges (subscribers receive done) when disposed', () async {
      final localClock = _FakeClockTickService();
      final localHeart = _FakeHeartRateTickService();
      addTearDown(localHeart.closeActiveSourceController);
      final localSut = SwitchableTickService(clock: localClock, heart: localHeart);

      bool done = false;
      localSut.sourceChanges.listen((_) {}, onDone: () => done = true);

      localSut.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
    });

    test(
      'should stop reacting to hasActiveSourceStream after dispose',
      () async {
        final localClock = _FakeClockTickService();
        final localHeart = _FakeHeartRateTickService();
        addTearDown(localHeart.closeActiveSourceController);
        final localSut = SwitchableTickService(clock: localClock, heart: localHeart);

        // Switch to heartbeat so that a false emission WOULD trigger fallback if subscribed.
        localHeart.hasActiveSource = true;
        localSut.trySwitchTo(TickSource.heartbeat);
        expect(localSut.source, TickSource.heartbeat);

        // Dispose cancels _healthSub — any subsequent emission is ignored.
        localSut.dispose();

        // Emit false after dispose. The health subscription is already cancelled,
        // so _switchInternal is never called and _activeSource stays at heartbeat.
        localHeart.emitHasActiveSource(false);
        await Future<void>.delayed(Duration.zero);

        // No fallback: source is still heartbeat (field not modified after dispose).
        expect(localSut.source, TickSource.heartbeat);
      },
    );
  });
}
