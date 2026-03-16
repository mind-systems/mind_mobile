import 'dart:async';
import 'dart:developer' as dev;

import 'ILiveBreathSessionService.dart';
import 'IBreathTelemetryService.dart';
import 'Models/BreathSessionState.dart';

class LiveBreathSessionCoordinator {
  final ILiveBreathSessionService liveSessionService;
  final IBreathTelemetryService telemetryService;
  final String sessionId;

  StreamSubscription<BreathSessionState>? _subscription;
  StreamSubscription<LiveBreathSessionDto>? _liveSessionSub;
  String? _liveSessionId;
  bool _started = false;
  bool _ended = false;
  BreathSessionStatus? _previousStatus;
  BreathPhase? _previousPhase;
  int? _previousExerciseIndex;
  BreathSessionState? _pendingTelemetry;

  LiveBreathSessionCoordinator({
    required this.liveSessionService,
    required this.telemetryService,
    required this.sessionId,
  });

  void start(Stream<BreathSessionState> stateStream) {
    assert(_subscription == null, 'LiveBreathSessionCoordinator.start() called twice');
    _subscription = stateStream.listen(_onState);
    _liveSessionSub = liveSessionService.sessionStateStream.listen((dto) {
      _liveSessionId = dto.liveSessionId;
      final liveId = dto.liveSessionId;
      if (liveId != null) _flushPending(liveId);
    });
  }

  void _onState(BreathSessionState state) {
    if (state.loadState != SessionLoadState.ready) return;
    _handleLifecycle(state.status);
    _handleTelemetry(state);
    _previousStatus = state.status;
    _previousPhase = state.phase;
    _previousExerciseIndex = state.exerciseIndex;
  }

  void _handleLifecycle(BreathSessionStatus status) {
    if (status == _previousStatus) return;

    final isActive = status == BreathSessionStatus.breath ||
        status == BreathSessionStatus.rest;
    final wasActive = _previousStatus == BreathSessionStatus.breath ||
        _previousStatus == BreathSessionStatus.rest;
    final wasPaused = _previousStatus == BreathSessionStatus.pause ||
        _previousStatus == null;

    if (wasPaused && isActive) {
      if (!_started) {
        dev.log('LiveBreathSessionCoordinator: session start [$sessionId]', name: 'LiveSession');
        liveSessionService.startSession(sessionId);
        _started = true;
      } else {
        dev.log('LiveBreathSessionCoordinator: session resume [$sessionId]', name: 'LiveSession');
        liveSessionService.resumeSession();
      }
    } else if (wasActive && status == BreathSessionStatus.pause) {
      if (_started && !_ended) {
        dev.log('LiveBreathSessionCoordinator: session pause [$sessionId]', name: 'LiveSession');
        liveSessionService.pauseSession();
      }
    } else if (status == BreathSessionStatus.complete) {
      if (_started && !_ended) {
        dev.log('LiveBreathSessionCoordinator: session end [$sessionId]', name: 'LiveSession');
        liveSessionService.endSession();
        _ended = true;
      }
    }
  }

  void _handleTelemetry(BreathSessionState state) {
    final liveId = _liveSessionId;
    final isActive = state.status == BreathSessionStatus.breath ||
        state.status == BreathSessionStatus.rest;
    if (!isActive || !_started || _ended) return;

    final phaseChanged = state.phase != _previousPhase ||
        state.exerciseIndex != _previousExerciseIndex;
    if (!phaseChanged) return;

    if (liveId == null) {
      _pendingTelemetry = state;
      return;
    }
    telemetryService.sendSample(liveId, state.phase.name, state.currentIntervalMs);
  }

  void _flushPending(String liveId) {
    final pending = _pendingTelemetry;
    if (pending == null) return;
    _pendingTelemetry = null;
    telemetryService.sendSample(liveId, pending.phase.name, pending.currentIntervalMs);
  }

  void reset() {
    _pendingTelemetry = null;
    _started = false;
    _ended = false;
    _previousStatus = null;
    _previousPhase = null;
    _previousExerciseIndex = null;
    // subscription stays alive — stream is reused across restart
  }

  void dispose() {
    if (_started && !_ended) {
      dev.log('LiveBreathSessionCoordinator: dispose — stopping session [$sessionId]', name: 'LiveSession');
      liveSessionService.stopSession();
    }
    _pendingTelemetry = null;
    _subscription?.cancel();
    _liveSessionSub?.cancel();
  }
}
