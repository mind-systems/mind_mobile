import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind/Core/Grpc/BackoffConfig.dart';
import 'package:mind/Core/Grpc/GrpcConnectionManager.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Models/User.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeTimer implements Timer {
  @override
  void cancel() {}

  @override
  int get tick => 0;

  @override
  bool get isActive => true;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

User get _authenticatedUser => User(
      id: 'user-id',
      email: 'test@example.com',
      name: 'Test User',
      language: 'en',
      isGuest: false,
    );

User get _guestUser => User(
      id: 'guest-id',
      email: '',
      name: 'Guest',
      language: '',
      isGuest: true,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late StreamController<AuthState> authCtrl;
  late StreamController<List<ConnectivityResult>> connectCtrl;
  late StreamController<void> resumeCtrl;
  late List<({Duration delay, void Function() callback})> timers;
  late GrpcConnectionManager manager;

  setUp(() {
    authCtrl = StreamController<AuthState>.broadcast();
    connectCtrl = StreamController<List<ConnectivityResult>>.broadcast();
    resumeCtrl = StreamController<void>.broadcast();
    timers = [];
    manager = GrpcConnectionManager(
      authStream: authCtrl.stream,
      connectivityStream: connectCtrl.stream,
      resumeStream: resumeCtrl.stream,
      backoffConfig: BackoffConfig(
        initialDelay: const Duration(milliseconds: 10),
        maxDelay: const Duration(milliseconds: 100),
        random: Random(0),
      ),
      timerFactory: (d, cb) {
        timers.add((delay: d, callback: cb));
        return FakeTimer();
      },
    );
  });

  tearDown(() async {
    manager.dispose();
    await authCtrl.close();
    await connectCtrl.close();
    await resumeCtrl.close();
  });

  /// Emits AuthenticatedState and waits for the stream listener to run.
  Future<void> authenticate() async {
    authCtrl.add(AuthenticatedState(_authenticatedUser));
    await Future.delayed(Duration.zero);
  }

  // =========================================================================
  // Phase 1 — delay progression (Tasks 1-4)
  // =========================================================================

  group('backoff delay progression', () {
    test(
        'should schedule a non-decreasing delay sequence across attempts 0–8',
        () async {
      await authenticate();

      for (var i = 0; i < 9; i++) {
        manager.scheduleReconnect();
      }

      expect(timers.length, 9);

      // Every delay must be in [0, 100ms].
      for (final t in timers) {
        expect(t.delay, greaterThanOrEqualTo(Duration.zero));
        expect(t.delay, lessThanOrEqualTo(const Duration(milliseconds: 100)));
      }

      // First delay should be in the attempt-0 range (~10ms base ±2.5ms).
      expect(timers[0].delay.inMilliseconds, lessThan(20));

      // Later attempts should be substantially larger.
      expect(timers[4].delay.inMilliseconds, greaterThan(timers[0].delay.inMilliseconds));
      expect(timers[8].delay.inMilliseconds, greaterThan(timers[0].delay.inMilliseconds));
    });

    test(
        'should cap the exponent at 6 so attempt 6 and attempt 7 produce equal nominal delays',
        () async {
      await authenticate();

      // Schedule 8 times.  At attempt 6 (index 6) and attempt 7 (index 7),
      // exp is clamped to 6, so the nominal base is 10 × 2^6 = 640 → clamped to 100 ms.
      for (var i = 0; i < 8; i++) {
        manager.scheduleReconnect();
      }

      expect(timers.length, 8);

      // Both should be in the maxDelay neighbourhood (100ms ± 25ms jitter, then
      // re-clamped to [0, 100]).
      expect(timers[6].delay.inMilliseconds, greaterThan(50));
      expect(timers[7].delay.inMilliseconds, greaterThan(50));
      expect(timers[6].delay, lessThanOrEqualTo(const Duration(milliseconds: 100)));
      expect(timers[7].delay, lessThanOrEqualTo(const Duration(milliseconds: 100)));
    });

    test(
        'should clamp every scheduled delay to maxDelay when 100ms ceiling is reached',
        () async {
      await authenticate();

      for (var i = 0; i < 10; i++) {
        manager.scheduleReconnect();
      }

      for (final t in timers) {
        expect(t.delay, lessThanOrEqualTo(const Duration(milliseconds: 100)));
      }
    });

    test('should never schedule a negative delay', () async {
      await authenticate();

      for (var i = 0; i < 9; i++) {
        manager.scheduleReconnect();
      }

      for (final t in timers) {
        expect(t.delay, greaterThanOrEqualTo(Duration.zero));
      }
    });
  });

  // =========================================================================
  // Phase 1 — overflow guard (Task 2)
  // =========================================================================

  group('overflow guard', () {
    test(
        'should complete 100 consecutive scheduleReconnect() calls without throwing',
        () async {
      await authenticate();

      expect(() {
        for (var i = 0; i < 100; i++) {
          manager.scheduleReconnect();
        }
      }, returnsNormally);

      expect(timers.length, 100);
      for (final t in timers) {
        expect(t.delay, lessThanOrEqualTo(const Duration(milliseconds: 100)));
      }
    });
  });

  // =========================================================================
  // Phase 1 — confirmConnected resets backoff (Task 3)
  // =========================================================================

  group('confirmConnected resets backoff', () {
    test(
        'should reset the attempt counter so the next delay matches the attempt-0 delay after confirmConnected()',
        () async {
      await authenticate();

      // Escalate to attempt 4 — delays should be in the 80–100 ms range.
      for (var i = 0; i < 4; i++) {
        manager.scheduleReconnect();
      }

      expect(timers.length, 4);
      final escalatedDelay = timers[3].delay;

      // Reset the backoff counter.
      manager.confirmConnected();

      // The next call should use attempt-0 logic: base=10ms, jitter=±2.5ms.
      manager.scheduleReconnect();
      final resetDelay = timers[4].delay;

      // Reset delay must be clearly in the attempt-0 band, not the escalated range.
      expect(resetDelay.inMilliseconds, lessThan(20));
      expect(resetDelay.inMilliseconds, lessThan(escalatedDelay.inMilliseconds));
    });
  });

  // =========================================================================
  // Phase 1 — no schedule when unauthenticated (Task 4)
  // =========================================================================

  group('no schedule when unauthenticated', () {
    test(
        'should not schedule a timer when scheduleReconnect() is called before any AuthenticatedState',
        () {
      manager.scheduleReconnect();
      expect(timers, isEmpty);
    });

    test('should not schedule a timer after GuestState is emitted', () async {
      // Authenticate first — connect() fires but creates no timer.
      await authenticate();
      expect(timers, isEmpty);

      // Log out — _isAuthenticated becomes false.
      authCtrl.add(GuestState(_guestUser));
      await Future.delayed(Duration.zero);

      final countBeforeCall = timers.length;

      // scheduleReconnect after logout must not add a timer.
      manager.scheduleReconnect();

      expect(timers.length, countBeforeCall);
    });
  });
}
