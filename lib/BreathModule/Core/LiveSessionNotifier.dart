import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'package:mind/BreathModule/Core/LiveSessionEvent.dart';
import 'package:mind/BreathModule/Core/LiveSessionState.dart';
import 'package:mind/Core/Socket/LiveSocketService.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/UserNotifier.dart';

class LiveSessionNotifier {
  final LiveSocketService _liveSocketService;

  late final StreamSubscription<Map<String, dynamic>> _subscription;
  late final StreamSubscription<AuthState> _authSubscription;

  bool _isPendingStart = false;

  final _state = BehaviorSubject<LiveSessionState>.seeded(LiveSessionState.initial());
  final _events = PublishSubject<LiveSessionEvent>();

  Stream<LiveSessionState> get stream => _state.stream;
  Stream<LiveSessionEvent> get events => _events.stream;
  LiveSessionState get currentState => _state.value;

  LiveSessionNotifier({required LiveSocketService liveSocketService, required UserNotifier userNotifier})
      : _liveSocketService = liveSocketService {
    _subscription = _liveSocketService.sessionStateEvents.listen(_onSessionState);
    _authSubscription = userNotifier.stream.listen((auth) { if (auth is GuestState) reset(); });
  }

  void reset() {
    _isPendingStart = false;
    _state.add(LiveSessionState.initial());
  }

  void start(String activityRefType, String activityRefId) {
    if (currentState.status == LiveSessionStatus.active || _isPendingStart) return;
    _isPendingStart = true;
    _liveSocketService.emitLive('activity:start', {
      'activityRefType': activityRefType,
      'activityRefId': activityRefId,
    });
  }

  void end() {
    if (currentState.status == LiveSessionStatus.idle) return;
    _liveSocketService.emitLive('activity:end');
  }

  void _onSessionState(Map<String, dynamic> data) {
    final status = data['status'] as String?;
    final liveSessionId = data['liveSessionId'] as String?;

    if (status == 'active') {
      final isNew = currentState.status != LiveSessionStatus.active;
      _isPendingStart = false;
      _state.add(LiveSessionState(liveSessionId: liveSessionId, status: LiveSessionStatus.active));
      if (isNew) {
        _events.add(LiveSessionStarted(liveSessionId: liveSessionId));
      }
    } else if (status == 'resumed') {
      _isPendingStart = false;
      final isNew = currentState.status != LiveSessionStatus.active;
      _state.add(LiveSessionState(liveSessionId: liveSessionId, status: LiveSessionStatus.active));
      if (isNew) {
        _events.add(LiveSessionStarted(liveSessionId: liveSessionId));
      }
    } else if (status == 'ended') {
      _state.add(LiveSessionState.initial());
      _events.add(LiveSessionEnded());
    } else if (status == 'abandoned') {
      _state.add(LiveSessionState.initial());
      _events.add(LiveSessionAbandoned());
    }
  }

  void dispose() {
    _subscription.cancel();
    _authSubscription.cancel();
    _state.close();
    _events.close();
  }
}
