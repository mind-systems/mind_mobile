import 'dart:async';
import 'dart:developer' as dev;

import 'ILiveSessionService.dart';
import 'ITelemetryService.dart';
import 'Models/BreathSessionState.dart';

class LiveSessionCoordinator {
  final ILiveSessionService liveSessionService;
  final ITelemetryService telemetryService;
  final String sessionId;

  StreamSubscription<BreathSessionState>? _subscription;
  bool _started = false;
  bool _ended = false;
  BreathSessionStatus? _previousStatus;
  BreathPhase? _previousPhase;
  int? _previousExerciseIndex;

  LiveSessionCoordinator({
    required this.liveSessionService,
    required this.telemetryService,
    required this.sessionId,
  });

  void start(Stream<BreathSessionState> stateStream) {
    _subscription = stateStream.listen(_onState);
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
        dev.log('LiveSessionCoordinator: session start [$sessionId]', name: 'LiveSession');
        liveSessionService.startSession(sessionId);
        _started = true;
      } else {
        dev.log('LiveSessionCoordinator: session resume [$sessionId]', name: 'LiveSession');
        liveSessionService.resumeSession();
      }
    } else if (wasActive && status == BreathSessionStatus.pause) {
      if (_started && !_ended) {
        dev.log('LiveSessionCoordinator: session pause [$sessionId]', name: 'LiveSession');
        liveSessionService.pauseSession();
      }
    } else if (status == BreathSessionStatus.complete) {
      if (_started && !_ended) {
        dev.log('LiveSessionCoordinator: session end [$sessionId]', name: 'LiveSession');
        liveSessionService.endSession();
        _ended = true;
      }
    }
  }

  void _handleTelemetry(BreathSessionState state) {
    final isActive = state.status == BreathSessionStatus.breath ||
        state.status == BreathSessionStatus.rest;
    if (!isActive || !_started || _ended) return;

    final phaseChanged = state.phase != _previousPhase ||
        state.exerciseIndex != _previousExerciseIndex;
    if (phaseChanged) {
      telemetryService.sendSample(sessionId, state.phase.name, state.currentIntervalMs);
    }
  }

  void reset() {
    _started = false;
    _ended = false;
    _previousStatus = null;
    _previousPhase = null;
    _previousExerciseIndex = null;
    // subscription stays alive — stream is reused across restart
  }

  void dispose() {
    if (_started && !_ended) {
      dev.log('LiveSessionCoordinator: dispose — ending active session [$sessionId]', name: 'LiveSession');
      liveSessionService.endSession();
    }
    _subscription?.cancel();
  }
}
