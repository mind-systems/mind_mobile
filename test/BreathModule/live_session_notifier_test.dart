import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';

import 'package:mind/BreathModule/Core/LiveBreathSessionNotifier.dart';
import 'package:mind/BreathModule/Core/LiveBreathSessionEvent.dart';
import 'package:mind/BreathModule/Core/LiveBreathSessionState.dart';
import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/ILiveSessionService.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Models/User.dart';

// ---------------------------------------------------------------------------
// Fake socket service
// ---------------------------------------------------------------------------

class FakeLiveSessionService implements ILiveSessionService {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get sessionStateEvents => _controller.stream;

  final List<({ActivityType type, String? refId})> activityStartCalls = [];
  int activityEndCount = 0;
  int activityStopCount = 0;
  int activityPauseCount = 0;
  int activityResumeCount = 0;

  @override
  void sendActivityStart({required ActivityType type, String? refId}) {
    activityStartCalls.add((type: type, refId: refId));
  }

  @override
  void sendActivityEnd() {
    activityEndCount++;
  }

  @override
  void sendActivityStop() {
    activityStopCount++;
  }

  @override
  void sendActivityPause() {
    activityPauseCount++;
  }

  @override
  void sendActivityResume() {
    activityResumeCount++;
  }

  void resetCounts() {
    activityStartCalls.clear();
    activityEndCount = 0;
    activityStopCount = 0;
    activityPauseCount = 0;
    activityResumeCount = 0;
  }

  void injectServerMessage(Map<String, dynamic> data) => _controller.add(data);

  Future<void> dispose() => _controller.close();
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _guest = User(id: 'guest', email: '', name: 'Guest', language: '', isGuest: true);
final _user = User(id: 'user-1', email: 'a@b.com', name: 'A', language: '', isGuest: false);

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

({LiveBreathSessionNotifier notifier, FakeLiveSessionService socket, BehaviorSubject<AuthState> authSubject})
    _make() {
  final socket = FakeLiveSessionService();
  final authSubject = BehaviorSubject<AuthState>.seeded(AuthenticatedState(_user));
  final notifier = LiveBreathSessionNotifier(liveSessionService: socket, authStream: authSubject.stream);
  return (notifier: notifier, socket: socket, authSubject: authSubject);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('start()', () {
    test('emits sendActivityStart to socket with correct payload', () {
      final (:notifier, :socket, :authSubject) = _make();

      notifier.start(type: ActivityType.breath, refId: 'session-abc');

      expect(socket.activityStartCalls, hasLength(1));
      expect(socket.activityStartCalls.first.type, ActivityType.breath);
      expect(socket.activityStartCalls.first.refId, 'session-abc');

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('second start() before server ACK does not emit again', () {
      final (:notifier, :socket, :authSubject) = _make();

      notifier.start(type: ActivityType.breath, refId: 'session-abc');
      notifier.start(type: ActivityType.breath, refId: 'session-abc');

      expect(socket.activityStartCalls, hasLength(1));

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('does nothing if already active', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      socket.resetCounts();
      notifier.start(type: ActivityType.breath, refId: 'session-abc');

      expect(socket.activityStartCalls, isEmpty);

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });
  });

  group('server message → active (new session)', () {
    test('state becomes active, isPaused: false', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      expect(notifier.currentState.status, LiveBreathSessionStatus.active);
      expect(notifier.currentState.isPaused, isFalse);
      expect(notifier.currentState.liveSessionId, 'live-1');

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('clears _isPendingStart', () async {
      final (:notifier, :socket, :authSubject) = _make();
      notifier.start(type: ActivityType.breath, refId: 'session-abc');
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      // After ACK, a new start() should be allowed (pending cleared)
      socket.resetCounts();
      // Can't start again while active, but pending flag is cleared — verify by resetting
      // to idle first then trying
      socket.injectServerMessage({'status': 'idle'});
      await Future.delayed(Duration.zero);
      notifier.start(type: ActivityType.breath, refId: 'session-abc');
      expect(socket.activityStartCalls, hasLength(1));

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('emits LiveBreathSessionStarted event with liveSessionId', () async {
      final (:notifier, :socket, :authSubject) = _make();
      final events = <LiveBreathSessionEvent>[];
      notifier.events.listen(events.add);

      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first, isA<LiveBreathSessionStarted>());
      expect((events.first as LiveBreathSessionStarted).liveSessionId, 'live-1');

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });
  });

  group('server message → active (resume from paused)', () {
    test('emits LiveBreathSessionUnpaused when isPaused transitions false→true→false', () async {
      final (:notifier, :socket, :authSubject) = _make();
      final events = <LiveBreathSessionEvent>[];
      notifier.events.listen(events.add);

      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': true});
      await Future.delayed(Duration.zero);
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      expect(events.last, isA<LiveBreathSessionUnpaused>());

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });
  });

  group('server message → active (pause)', () {
    test('emits LiveBreathSessionPaused when isPaused transitions false→true', () async {
      final (:notifier, :socket, :authSubject) = _make();
      final events = <LiveBreathSessionEvent>[];
      notifier.events.listen(events.add);

      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': true});
      await Future.delayed(Duration.zero);

      expect(events.last, isA<LiveBreathSessionPaused>());

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });
  });

  group('pause()', () {
    test('calls sendActivityPause on socket', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      socket.resetCounts();
      notifier.pause();

      expect(socket.activityPauseCount, 1);

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('second pause() before ACK does not emit again', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      socket.resetCounts();
      notifier.pause();
      notifier.pause();

      expect(socket.activityPauseCount, 1);

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('does nothing if already paused', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': true});
      await Future.delayed(Duration.zero);

      socket.resetCounts();
      notifier.pause();

      expect(socket.activityPauseCount, 0);

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('does nothing if not active', () {
      final (:notifier, :socket, :authSubject) = _make();

      notifier.pause();

      expect(socket.activityPauseCount, 0);

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });
  });

  group('unpause()', () {
    test('calls sendActivityResume on socket', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': true});
      await Future.delayed(Duration.zero);

      socket.resetCounts();
      notifier.unpause();

      expect(socket.activityResumeCount, 1);

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('does nothing if not paused', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      socket.resetCounts();
      notifier.unpause();

      expect(socket.activityResumeCount, 0);

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });
  });

  group('end()', () {
    test('calls sendActivityEnd on socket', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      socket.resetCounts();
      notifier.end();

      expect(socket.activityEndCount, 1);

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('does nothing if status is idle', () {
      final (:notifier, :socket, :authSubject) = _make();

      notifier.end();

      expect(socket.activityEndCount, 0);

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });
  });

  group('server message → ended', () {
    test('state resets to initial', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      socket.injectServerMessage({'status': 'ended'});
      await Future.delayed(Duration.zero);

      expect(notifier.currentState.status, LiveBreathSessionStatus.idle);
      expect(notifier.currentState.liveSessionId, isNull);

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('emits LiveBreathSessionEnded event', () async {
      final (:notifier, :socket, :authSubject) = _make();
      final events = <LiveBreathSessionEvent>[];
      notifier.events.listen(events.add);

      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);
      socket.injectServerMessage({'status': 'ended'});
      await Future.delayed(Duration.zero);

      expect(events.last, isA<LiveBreathSessionEnded>());

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });
  });

  group('server message → abandoned', () {
    test('state resets to initial', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      socket.injectServerMessage({'status': 'abandoned'});
      await Future.delayed(Duration.zero);

      expect(notifier.currentState.status, LiveBreathSessionStatus.idle);

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('emits LiveBreathSessionAbandoned event', () async {
      final (:notifier, :socket, :authSubject) = _make();
      final events = <LiveBreathSessionEvent>[];
      notifier.events.listen(events.add);

      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);
      socket.injectServerMessage({'status': 'abandoned'});
      await Future.delayed(Duration.zero);

      expect(events.last, isA<LiveBreathSessionAbandoned>());

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });
  });

  group('server message → idle', () {
    test('state resets to initial', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      socket.injectServerMessage({'status': 'idle'});
      await Future.delayed(Duration.zero);

      expect(notifier.currentState.status, LiveBreathSessionStatus.idle);

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('clears _isPendingStart and no event emitted', () async {
      final (:notifier, :socket, :authSubject) = _make();
      final events = <LiveBreathSessionEvent>[];
      notifier.events.listen(events.add);

      notifier.start(type: ActivityType.breath, refId: 'session-abc');
      socket.injectServerMessage({'status': 'idle'});
      await Future.delayed(Duration.zero);

      // No events emitted (idle does not produce an event)
      expect(events, isEmpty);
      // Pending cleared — another start() should now emit
      socket.resetCounts();
      notifier.start(type: ActivityType.breath, refId: 'session-abc');
      expect(socket.activityStartCalls, hasLength(1));

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });
  });

  group('reset() / logout', () {
    test('GuestState from authStream triggers reset()', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);
      expect(notifier.currentState.status, LiveBreathSessionStatus.active);

      authSubject.add(GuestState(_guest));
      await Future.delayed(Duration.zero);

      expect(notifier.currentState.status, LiveBreathSessionStatus.idle);
      expect(notifier.currentState.liveSessionId, isNull);

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });
  });
}
