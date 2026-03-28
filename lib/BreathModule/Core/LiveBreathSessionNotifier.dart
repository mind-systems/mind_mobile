import 'dart:async';
import 'dart:developer';

import 'package:rxdart/rxdart.dart';

import 'package:mind/BreathModule/Core/LiveBreathSessionEvent.dart';
import 'package:mind/BreathModule/Core/LiveBreathSessionState.dart';
import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/ILiveSessionService.dart';
import 'package:mind/User/Models/AuthState.dart';

class LiveBreathSessionNotifier {
  final ILiveSessionService _liveSessionService;

  late final StreamSubscription<Map<String, dynamic>> _subscription;
  late final StreamSubscription<AuthState> _authSubscription;

  bool _isPendingStart = false;
  bool _isPendingPause = false;

  final _state = BehaviorSubject<LiveBreathSessionState>.seeded(LiveBreathSessionState.initial());
  final _events = PublishSubject<LiveBreathSessionEvent>();

  Stream<LiveBreathSessionState> get stream => _state.stream;
  Stream<LiveBreathSessionEvent> get events => _events.stream;
  LiveBreathSessionState get currentState => _state.value;

  LiveBreathSessionNotifier({required ILiveSessionService liveSessionService, required Stream<AuthState> authStream})
      : _liveSessionService = liveSessionService {
    _subscription = _liveSessionService.sessionStateEvents.listen(_onSessionState);
    _authSubscription = authStream.listen((auth) { if (auth is GuestState) reset(); });
  }

  void reset() {
    _isPendingStart = false;
    _isPendingPause = false;
    _state.add(LiveBreathSessionState.initial());
  }

  void start({required ActivityType type, required String refId}) {
    if (currentState.status == LiveBreathSessionStatus.active || _isPendingStart) return;
    _isPendingStart = true;
    _liveSessionService.sendActivityStart(type: type, refId: refId);
  }

  void pause() {
    if (currentState.status != LiveBreathSessionStatus.active || currentState.isPaused || _isPendingPause) return;
    _isPendingPause = true;
    _liveSessionService.sendActivityPause();
  }

  void unpause() {
    if (!currentState.isPaused) return;
    _isPendingPause = false;
    _liveSessionService.sendActivityResume();
  }

  void end() {
    if (currentState.status == LiveBreathSessionStatus.idle) return;
    _liveSessionService.sendActivityEnd();
  }

  void stop() {
    if (currentState.status == LiveBreathSessionStatus.idle) return;
    _liveSessionService.sendActivityStop();
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
    } else if (status == 'interrupted') {
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
