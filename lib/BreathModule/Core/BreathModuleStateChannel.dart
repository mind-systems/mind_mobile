import 'dart:async';

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Logger.dart';
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
  String? _moduleSessionId;
  ({BreathSessionState state, int offsetMs})? _pendingInstruction;

  final Stopwatch _stopwatch = Stopwatch();
  DateTime? _originWallClock;

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
      _moduleSessionId = moduleState.moduleSessionId;
      final sessionId = moduleState.moduleSessionId;
      if (sessionId != null) _flushPending(sessionId);
    });
  }

  String? get moduleSessionId => _moduleSessionId;

  void _onState(BreathSessionState state) {
    if (state.loadState != SessionLoadState.ready) return;
    _handleLifecycle(state.status);
    _handleInstruction(state);
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
        logPrint('[BreathModuleState] BreathModuleStateChannel: session start [$_sessionId]');
        _stopwatch..reset()..start();
        _originWallClock = DateTime.now();
        _channel.start(type: ActivityType.breath, refId: _sessionId);
        _started = true;
        _previousPhase = null;
        _previousExerciseIndex = null;
      } else {
        logPrint('[BreathModuleState] BreathModuleStateChannel: session resume [$_sessionId]');
        _channel.unpause();
      }
    } else if (wasActive && status == BreathSessionStatus.pause) {
      if (_started && !_ended) {
        logPrint('[BreathModuleState] BreathModuleStateChannel: session pause [$_sessionId]');
        _channel.pause();
      }
    } else if (status == BreathSessionStatus.complete) {
      if (_started && !_ended) {
        logPrint('[BreathModuleState] BreathModuleStateChannel: session end [$_sessionId]');
        _channel.end();
        _ended = true;
      }
    }
  }

  void _handleInstruction(BreathSessionState state) {
    final sessionId = _moduleSessionId;
    final isActive = state.status == BreathSessionStatus.breath ||
        state.status == BreathSessionStatus.rest;
    if (!isActive || !_started || _ended) return;

    final phaseChanged = state.phase != _previousPhase ||
        state.exerciseIndex != _previousExerciseIndex;
    if (!phaseChanged) return;

    final offsetMs = _stopwatch.elapsedMilliseconds;

    if (sessionId == null) {
      _pendingInstruction = (state: state, offsetMs: offsetMs);
      return;
    }
    _instructionStream.sendSample(sessionId, state.phase.name, state.currentPhaseTotalDuration, offsetMs, _wireTimestamp(offsetMs));
  }

  void _flushPending(String sessionId) {
    final pending = _pendingInstruction;
    if (pending == null) return;
    _pendingInstruction = null;
    _instructionStream.sendSample(sessionId, pending.state.phase.name, pending.state.currentPhaseTotalDuration, pending.offsetMs, _wireTimestamp(pending.offsetMs));
  }

  int _wireTimestamp(int offsetMs) =>
      (_originWallClock?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch) + offsetMs;

  void reset() {
    _moduleSessionId = null;
    _started = false;
    _ended = false;
    _previousStatus = null;
    _previousPhase = null;
    _previousExerciseIndex = null;
    _pendingInstruction = null;
    _stopwatch..stop()..reset();
    _originWallClock = null;
    // Subscriptions stay alive — the stream is reused across restarts.
  }

  void dispose() {
    if (_started && !_ended) {
      logPrint('[BreathModuleState] BreathModuleStateChannel: dispose — stopping session [$_sessionId]');
      _channel.stop();
    }
    _stateSub.cancel();
    _channelSub.cancel();
  }
}
