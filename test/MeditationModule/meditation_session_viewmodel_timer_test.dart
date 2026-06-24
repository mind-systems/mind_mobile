import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meditation_module/meditation_module.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Fake timer
// ──────────────────────────────────────────────────────────────────────────────

class _FakeTimer implements Timer {
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

void main() {
  late DateTime now;
  late List<({Duration delay, void Function(Timer) cb})> timers;
  late List<_FakeTimer> fakeTimers;

  /// Spy timer factory — captures each armed timer and returns a controllable fake.
  Timer spyFactory(Duration d, void Function(Timer) cb) {
    final t = _FakeTimer();
    timers.add((delay: d, cb: cb));
    fakeTimers.add(t);
    return t;
  }

  /// Fires the most recently captured timer callback (if not cancelled).
  void fireLast() {
    if (timers.isEmpty) return;
    final last = fakeTimers.last;
    if (!last.cancelled) timers.last.cb(last);
  }

  late ProviderContainer container;
  late MeditationSessionViewModel vm;

  setUp(() {
    now = DateTime(2026, 1, 1);
    timers = [];
    fakeTimers = [];
    container = ProviderContainer(
      overrides: [
        meditationSessionViewModelProvider.overrideWith(
          () => MeditationSessionViewModel(
            poseId: 'test-pose',
            clock: () => now,
            timerFactory: spyFactory,
          ),
        ),
      ],
    );
    // Trigger build() so ref.onDispose is registered.
    vm = container.read(meditationSessionViewModelProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  // ── Phase 1: start() arming & clock capture ───────────────────────────────

  group('MeditationSessionViewModel — start() arming & clock capture', () {
    test('should set status to active when start() is called', () {
      vm.start();
      final state = container.read(meditationSessionViewModelProvider);
      expect(state.status, MeditationSessionStatus.active);
    });

    test('should reset elapsedSeconds to 0 when start() is called', () {
      vm.elapsedSeconds.value = 99;
      vm.start();
      expect(vm.elapsedSeconds.value, 0);
    });

    test(
      'should arm exactly one periodic timer with a 1-second interval when start() is called',
      () {
        vm.start();
        expect(timers, hasLength(1));
        expect(timers.first.delay, const Duration(seconds: 1));
      },
    );

    test(
      'should capture _startedAt from clock() at start so the first fire counts from that instant',
      () {
        vm.start(); // captures now = T
        now = now.add(const Duration(seconds: 3)); // advance to T + 3s
        fireLast(); // fire the timer callback once
        expect(vm.elapsedSeconds.value, 3);
      },
    );

    test(
      'should emit the active state to the stream when start() is called',
      () async {
        final states = <MeditationSessionState>[];
        vm.stream.listen(states.add);
        vm.start();
        await Future<void>.delayed(Duration.zero);
        expect(states, hasLength(1));
        expect(states.first.status, MeditationSessionStatus.active);
      },
    );
  });

  // ── Phase 2: timer callback wall-clock delta (core regression guard) ───────

  group('MeditationSessionViewModel — timer callback wall-clock delta', () {
    test(
      'should set elapsedSeconds to the wall-clock delta on each timer fire',
      () {
        vm.start(); // captures now = T
        now = now.add(const Duration(seconds: 5));
        fireLast(); // → 5
        expect(vm.elapsedSeconds.value, 5);
        now = now.add(const Duration(seconds: 4)); // T + 9
        fireLast(); // → 9
        expect(vm.elapsedSeconds.value, 9);
      },
    );

    test(
      'should report 30 when clock advances 30s but only 5 callbacks fire',
      () {
        vm.start();
        now = now.add(const Duration(seconds: 30));
        for (var i = 0; i < 5; i++) fireLast();
        // Wall-clock delta, not per-fire accumulator — must be 30, not 5.
        expect(vm.elapsedSeconds.value, 30);
      },
    );

    test(
      'should recompute from the delta and ignore externally mutated elapsedSeconds when a tick fires',
      () {
        vm.start(); // captures now = T
        now = now.add(const Duration(seconds: 1));
        fireLast(); // → 1
        vm.elapsedSeconds.value = 99; // external mutation
        now = now.add(const Duration(seconds: 1)); // T + 2
        fireLast(); // → 2, not 100
        expect(vm.elapsedSeconds.value, 2);
      },
    );

    test(
      'should read the same _startedAt for multiple fires in rapid succession with no clock change',
      () {
        vm.start();
        now = now.add(const Duration(seconds: 4));
        fireLast();
        expect(vm.elapsedSeconds.value, 4);
        fireLast(); // same clock — delta unchanged
        expect(vm.elapsedSeconds.value, 4);
        fireLast();
        expect(vm.elapsedSeconds.value, 4);
      },
    );

    test(
      'should monotonically increase elapsedSeconds across successive fires as the clock advances',
      () {
        vm.start();
        now = now.add(const Duration(seconds: 1));
        fireLast();
        expect(vm.elapsedSeconds.value, 1);
        now = now.add(const Duration(seconds: 1)); // T + 2
        fireLast();
        expect(vm.elapsedSeconds.value, 2);
        now = now.add(const Duration(seconds: 8)); // T + 10
        fireLast();
        expect(vm.elapsedSeconds.value, 10);
        // Never backslides — final value is the largest.
        expect(vm.elapsedSeconds.value, greaterThanOrEqualTo(2));
      },
    );
  });

  // ── Phase 3: stop() teardown ──────────────────────────────────────────────

  group('MeditationSessionViewModel — stop() teardown', () {
    test('should cancel the armed timer when stop() is called', () {
      vm.start();
      vm.stop();
      expect(fakeTimers.last.isActive, isFalse);
      expect(fakeTimers.last.cancelled, isTrue);
    });

    test('should set status to idle when stop() is called', () {
      vm.start();
      vm.stop();
      final state = container.read(meditationSessionViewModelProvider);
      expect(state.status, MeditationSessionStatus.idle);
    });

    test('should preserve the last elapsedSeconds value after stop()', () {
      vm.start();
      now = now.add(const Duration(seconds: 3));
      fireLast(); // → 3
      expect(vm.elapsedSeconds.value, 3);
      vm.stop();
      expect(vm.elapsedSeconds.value, 3); // stop() does NOT reset to 0
    });

    test(
      'should emit the idle state to the stream when stop() is called',
      () async {
        final states = <MeditationSessionState>[];
        vm.stream.listen(states.add);
        vm.start();
        await Future<void>.delayed(Duration.zero);
        states.clear(); // discard the active emission
        vm.stop();
        await Future<void>.delayed(Duration.zero);
        expect(states, hasLength(1));
        expect(states.first.status, MeditationSessionStatus.idle);
      },
    );

    test(
      'should clear _startedAt so no further elapsed updates occur after stop()',
      () {
        vm.start();
        now = now.add(const Duration(seconds: 3));
        fireLast(); // → 3
        vm.stop(); // cancels timer and nulls _startedAt
        // Timer is cancelled — advancing now without re-firing leaves elapsed unchanged.
        now = now.add(const Duration(seconds: 10));
        expect(vm.elapsedSeconds.value, 3); // still 3
      },
    );
  });

  // ── Phase 4: restart after stop() ────────────────────────────────────────

  group('MeditationSessionViewModel — restart after stop()', () {
    test(
      'should reset elapsedSeconds to 0 when start() is called again after stop()',
      () {
        vm.start();
        now = now.add(const Duration(seconds: 5));
        fireLast(); // → 5
        vm.stop();
        vm.start(); // restart
        expect(vm.elapsedSeconds.value, 0);
      },
    );

    test('should re-arm a fresh periodic timer on restart', () {
      vm.start();
      vm.stop();
      vm.start();
      expect(timers, hasLength(2)); // two separate arm calls
      expect(fakeTimers.first.isActive, isFalse); // first timer was cancelled
      expect(fakeTimers.last.isActive, isTrue); // new timer is active
    });

    test(
      'should re-capture _startedAt from the current clock on restart',
      () {
        // First cycle
        vm.start(); // T = 2026-01-01 00:00:00
        now = now.add(const Duration(seconds: 3)); // T + 3
        fireLast(); // → 3
        vm.stop();

        // Advance the gap so the restart is not at T + 3
        now = now.add(const Duration(seconds: 7)); // T + 10; this is the new start instant

        vm.start(); // re-captures _startedAt = T + 10
        now = now.add(const Duration(seconds: 2)); // T + 12
        fireLast(); // elapsed from new start = 2, not 12
        expect(vm.elapsedSeconds.value, 2);
      },
    );

    test('should set status back to active on restart', () {
      vm.start();
      vm.stop();
      vm.start();
      final state = container.read(meditationSessionViewModelProvider);
      expect(state.status, MeditationSessionStatus.active);
    });
  });
}
