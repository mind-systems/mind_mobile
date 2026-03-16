import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'package:mind/BreathModule/Core/LiveSessionEvent.dart';
import 'package:mind/BreathModule/Core/LiveSessionState.dart';
import 'package:mind/Core/Socket/ILiveSocketService.dart';
import 'package:mind/User/Models/AuthState.dart';

class LiveSessionNotifier {
  final ILiveSocketService _liveSocketService;

  late final StreamSubscription<Map<String, dynamic>> _subscription;
  late final StreamSubscription<AuthState> _authSubscription;

  bool _isPendingStart = false;
  bool _isPendingPause = false;

  final _state = BehaviorSubject<LiveSessionState>.seeded(LiveSessionState.initial());
  final _events = PublishSubject<LiveSessionEvent>();

  Stream<LiveSessionState> get stream => _state.stream;
  Stream<LiveSessionEvent> get events => _events.stream;
  LiveSessionState get currentState => _state.value;

  LiveSessionNotifier({required ILiveSocketService liveSocketService, required Stream<AuthState> authStream})
      : _liveSocketService = liveSocketService {
    _subscription = _liveSocketService.sessionStateEvents.listen(_onSessionState);
    _authSubscription = authStream.listen((auth) { if (auth is GuestState) reset(); });
  }

  void reset() {
    _isPendingStart = false;
    _isPendingPause = false;
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

  void pause() {
    if (currentState.status != LiveSessionStatus.active || currentState.isPaused || _isPendingPause) return;
    _isPendingPause = true;
    _liveSocketService.emitLive('activity:pause');
  }

  void unpause() {
    if (!currentState.isPaused) return;
    _isPendingPause = false;
    _liveSocketService.emitLive('activity:resume');
  }

  void end() {
    if (currentState.status == LiveSessionStatus.idle) return;
    _liveSocketService.emitLive('activity:end');
  }

  void _onSessionState(Map<String, dynamic> data) {
    final status = data['status'] as String?;
    final liveSessionId = data['liveSessionId'] as String?;

    if (status == 'active' || status == 'resumed') {
      final isPaused = (data['isPaused'] as bool?) ?? false;
      final wasPaused = currentState.isPaused;
      final isNew = currentState.status != LiveSessionStatus.active;
      _isPendingStart = false;
      _isPendingPause = false;
      _state.add(LiveSessionState(liveSessionId: liveSessionId, status: LiveSessionStatus.active, isPaused: isPaused));
      if (isNew) {
        _events.add(LiveSessionStarted(liveSessionId: liveSessionId));
      } else if (wasPaused && !isPaused) {
        _events.add(LiveSessionUnpaused());
      } else if (!wasPaused && isPaused) {
        _events.add(LiveSessionPaused());
      }
    } else if (status == 'ended') {
      _state.add(LiveSessionState.initial());
      _events.add(LiveSessionEnded());
    } else if (status == 'abandoned') {
      _state.add(LiveSessionState.initial());
      _events.add(LiveSessionAbandoned());
    } else if (status == 'idle') {
      _isPendingStart = false;
      _state.add(LiveSessionState.initial());
    }
  }

  void dispose() {
    _subscription.cancel();
    _authSubscription.cancel();
    _state.close();
    _events.close();
  }
}
