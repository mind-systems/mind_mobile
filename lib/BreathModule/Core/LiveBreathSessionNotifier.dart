import 'dart:async';
import 'dart:developer';

import 'package:rxdart/rxdart.dart';

import 'package:mind/BreathModule/Core/LiveBreathSessionEvent.dart';
import 'package:mind/BreathModule/Core/LiveBreathSessionState.dart';
import 'package:mind/Core/Socket/ILiveSocketService.dart';
import 'package:mind/User/Models/AuthState.dart';

class LiveBreathSessionNotifier {
  final ILiveSocketService _liveSocketService;

  late final StreamSubscription<Map<String, dynamic>> _subscription;
  late final StreamSubscription<AuthState> _authSubscription;

  bool _isPendingStart = false;
  bool _isPendingPause = false;

  final _state = BehaviorSubject<LiveBreathSessionState>.seeded(LiveBreathSessionState.initial());
  final _events = PublishSubject<LiveBreathSessionEvent>();

  Stream<LiveBreathSessionState> get stream => _state.stream;
  Stream<LiveBreathSessionEvent> get events => _events.stream;
  LiveBreathSessionState get currentState => _state.value;

  LiveBreathSessionNotifier({required ILiveSocketService liveSocketService, required Stream<AuthState> authStream})
      : _liveSocketService = liveSocketService {
    _subscription = _liveSocketService.sessionStateEvents.listen(_onSessionState);
    _authSubscription = authStream.listen((auth) { if (auth is GuestState) reset(); });
  }

  void reset() {
    _isPendingStart = false;
    _isPendingPause = false;
    _state.add(LiveBreathSessionState.initial());
  }

  void start(String activityType, String activityRefType, String activityRefId) {
    if (currentState.status == LiveBreathSessionStatus.active || _isPendingStart) return;
    _isPendingStart = true;
    _liveSocketService.emitLive('activity:start', {
      'activityType': activityType,
      'activityRefType': activityRefType,
      'activityRefId': activityRefId,
    });
  }

  void pause() {
    if (currentState.status != LiveBreathSessionStatus.active || currentState.isPaused || _isPendingPause) return;
    _isPendingPause = true;
    _liveSocketService.emitLive('activity:pause');
  }

  void unpause() {
    if (!currentState.isPaused) return;
    _isPendingPause = false;
    _liveSocketService.emitLive('activity:resume');
  }

  void end() {
    if (currentState.status == LiveBreathSessionStatus.idle) return;
    _liveSocketService.emitLive('activity:end');
  }

  void _onSessionState(Map<String, dynamic> data) {
    final status = data['status'] as String?;
    final liveSessionId = data['liveSessionId'] as String?;

    if (status == 'active' || status == 'resumed') {
      final isPaused = (data['isPaused'] as bool?) ?? false;
      final wasPaused = currentState.isPaused;
      final isNew = currentState.status != LiveBreathSessionStatus.active;
      _isPendingStart = false;
      _isPendingPause = false;
      _state.add(LiveBreathSessionState(liveSessionId: liveSessionId, status: LiveBreathSessionStatus.active, isPaused: isPaused));
      if (isNew) {
        _events.add(LiveBreathSessionStarted(liveSessionId: liveSessionId));
      } else if (wasPaused && !isPaused) {
        _events.add(LiveBreathSessionUnpaused());
      } else if (!wasPaused && isPaused) {
        _events.add(LiveBreathSessionPaused());
      }
    } else if (status == 'ended' || status == 'completed') {
      _state.add(LiveBreathSessionState.initial());
      _events.add(LiveBreathSessionEnded());
    } else if (status == 'abandoned') {
      _state.add(LiveBreathSessionState.initial());
      _events.add(LiveBreathSessionAbandoned());
    } else if (status == 'idle') {
      _isPendingStart = false;
      _state.add(LiveBreathSessionState.initial());
    } else {
      log('[LiveSession] unknown status: $status', name: 'LiveBreathSessionNotifier', level: 900);
    }
  }

  void dispose() {
    _subscription.cancel();
    _authSubscription.cancel();
    _state.close();
    _events.close();
  }
}
