import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';

import 'package:mind/BreathModule/Core/LiveBreathSessionNotifier.dart';
import 'package:mind/BreathModule/Core/LiveBreathSessionEvent.dart';
import 'package:mind/BreathModule/Core/LiveBreathSessionState.dart';
import 'package:mind/Core/Socket/ILiveSocketService.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Models/User.dart';

// ---------------------------------------------------------------------------
// Fake socket service
// ---------------------------------------------------------------------------

class FakeLiveSocketService implements ILiveSocketService {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get sessionStateEvents => _controller.stream;

  final List<(String, Map<String, dynamic>?)> emitted = [];

  @override
  void emitLive(String event, [Map<String, dynamic>? data]) {
    emitted.add((event, data));
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

({LiveBreathSessionNotifier notifier, FakeLiveSocketService socket, BehaviorSubject<AuthState> authSubject})
    _make() {
  final socket = FakeLiveSocketService();
  final authSubject = BehaviorSubject<AuthState>.seeded(AuthenticatedState(_user));
  final notifier = LiveBreathSessionNotifier(liveSocketService: socket, authStream: authSubject.stream);
  return (notifier: notifier, socket: socket, authSubject: authSubject);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('start()', () {
    test('emits activity:start to socket with correct payload', () {
      final (:notifier, :socket, :authSubject) = _make();

      notifier.start('breath_session', 'breath', 'session-abc');

      expect(socket.emitted, hasLength(1));
      expect(socket.emitted.first.$1, 'activity:start');
      expect(socket.emitted.first.$2, {'activityType': 'breath_session', 'activityRefType': 'breath', 'activityRefId': 'session-abc'});

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('second start() before server ACK does not emit again', () {
      final (:notifier, :socket, :authSubject) = _make();

      notifier.start('breath_session', 'breath', 'session-abc');
      notifier.start('breath_session', 'breath', 'session-abc');

      expect(socket.emitted, hasLength(1));

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('does nothing if already active', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      socket.emitted.clear();
      notifier.start('breath_session', 'breath', 'session-abc');

      expect(socket.emitted, isEmpty);

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
      notifier.start('breath_session', 'breath', 'session-abc');
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      // After ACK, a new start() should be allowed (pending cleared)
      socket.emitted.clear();
      // Can't start again while active, but pending flag is cleared — verify by resetting
      // to idle first then trying
      socket.injectServerMessage({'status': 'idle'});
      await Future.delayed(Duration.zero);
      notifier.start('breath_session', 'breath', 'session-abc');
      expect(socket.emitted, hasLength(1));

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
    test('emits activity:pause to socket', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      socket.emitted.clear();
      notifier.pause();

      expect(socket.emitted.first.$1, 'activity:pause');

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('second pause() before ACK does not emit again', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      socket.emitted.clear();
      notifier.pause();
      notifier.pause();

      expect(socket.emitted, hasLength(1));

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('does nothing if already paused', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': true});
      await Future.delayed(Duration.zero);

      socket.emitted.clear();
      notifier.pause();

      expect(socket.emitted, isEmpty);

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('does nothing if not active', () {
      final (:notifier, :socket, :authSubject) = _make();

      notifier.pause();

      expect(socket.emitted, isEmpty);

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });
  });

  group('unpause()', () {
    test('emits activity:resume to socket', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': true});
      await Future.delayed(Duration.zero);

      socket.emitted.clear();
      notifier.unpause();

      expect(socket.emitted.first.$1, 'activity:resume');

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('does nothing if not paused', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      socket.emitted.clear();
      notifier.unpause();

      expect(socket.emitted, isEmpty);

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });
  });

  group('end()', () {
    test('emits activity:end to socket', () async {
      final (:notifier, :socket, :authSubject) = _make();
      socket.injectServerMessage({'status': 'active', 'liveSessionId': 'live-1', 'isPaused': false});
      await Future.delayed(Duration.zero);

      socket.emitted.clear();
      notifier.end();

      expect(socket.emitted.first.$1, 'activity:end');

      notifier.dispose();
      socket.dispose();
      authSubject.close();
    });

    test('does nothing if status is idle', () {
      final (:notifier, :socket, :authSubject) = _make();

      notifier.end();

      expect(socket.emitted, isEmpty);

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

      notifier.start('breath_session', 'breath', 'session-abc');
      socket.injectServerMessage({'status': 'idle'});
      await Future.delayed(Duration.zero);

      // No events emitted (idle does not produce an event)
      expect(events, isEmpty);
      // Pending cleared — another start() should now emit
      socket.emitted.clear();
      notifier.start('breath_session', 'breath', 'session-abc');
      expect(socket.emitted, hasLength(1));

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
