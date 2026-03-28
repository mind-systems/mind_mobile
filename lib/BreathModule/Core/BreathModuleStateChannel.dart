import 'dart:async';
import 'dart:developer' as dev;

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/ModuleState.dart';
import 'package:mind/Core/Grpc/ModuleStateChannel.dart';
import 'package:mind/BreathModule/Core/BreathModuleInstructionStream.dart';
import 'package:breath_module/breath_module.dart' show BreathSessionState, BreathSessionStatus, BreathPhase, SessionLoadState;

class BreathModuleStateChannel {
  final ModuleStateChannel _channel;
  final BreathModuleInstructionStream _instructionStream;
  final String _sessionId;

  bool _started = false;
  bool _ended = false;
  BreathSessionStatus? _previousStatus;
  BreathPhase? _previousPhase;
  int? _previousExerciseIndex;
  String? _liveSessionId;
  BreathSessionState? _pendingTelemetry;

  late final StreamSubscription<BreathSessionState> _stateSub;
  late final StreamSubscription<ModuleState> _channelSub;

  BreathModuleStateChannel({
    required ModuleStateChannel channel,
    required Stream<BreathSessionState> stateStream,
    required BreathModuleInstructionStream instructionStream,
    required String sessionId,
  })  : _channel = channel,
        _instructionStream = instructionStream,
        _sessionId = sessionId {
    _stateSub = stateStream.listen(_onState);
    _channelSub = channel.state.listen((moduleState) {
      _liveSessionId = moduleState.liveSessionId;
      final liveId = moduleState.liveSessionId;
      if (liveId != null) _flushPending(liveId);
    });
  }

  String? get liveSessionId => _liveSessionId;

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
        dev.log('BreathModuleStateChannel: session start [$_sessionId]', name: 'LiveSession');
        _channel.start(type: ActivityType.breath, refId: _sessionId);
        _started = true;
      } else {
        dev.log('BreathModuleStateChannel: session resume [$_sessionId]', name: 'LiveSession');
        _channel.unpause();
      }
    } else if (wasActive && status == BreathSessionStatus.pause) {
      if (_started && !_ended) {
        dev.log('BreathModuleStateChannel: session pause [$_sessionId]', name: 'LiveSession');
        _channel.pause();
      }
    } else if (status == BreathSessionStatus.complete) {
      if (_started && !_ended) {
        dev.log('BreathModuleStateChannel: session end [$_sessionId]', name: 'LiveSession');
        _channel.end();
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
    _instructionStream.sendSample(liveId, state.phase.name, state.currentIntervalMs);
  }

  void _flushPending(String liveId) {
    final pending = _pendingTelemetry;
    if (pending == null) return;
    _pendingTelemetry = null;
    _instructionStream.sendSample(liveId, pending.phase.name, pending.currentIntervalMs);
  }

  void reset() {
    _liveSessionId = null;
    _started = false;
    _ended = false;
    _previousStatus = null;
    _previousPhase = null;
    _previousExerciseIndex = null;
    _pendingTelemetry = null;
    // Subscriptions stay alive — the stream is reused across restarts.
  }

  void dispose() {
    if (_started && !_ended) {
      dev.log('BreathModuleStateChannel: dispose — stopping session [$_sessionId]', name: 'LiveSession');
      _channel.stop();
    }
    _stateSub.cancel();
    _channelSub.cancel();
  }
}
