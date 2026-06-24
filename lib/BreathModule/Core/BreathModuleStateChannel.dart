import 'dart:async';

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Logger.dart';
import 'package:mind/Core/Grpc/ModuleState.dart';
import 'package:mind/Core/Grpc/ModuleStateChannel.dart';
import 'package:mind/Core/Grpc/ModuleStateEvent.dart';
import 'package:mind/BreathModule/Core/BreathModuleInstructionStream.dart';
import 'package:breath_module/breath_module.dart' show BreathSessionState, BreathSessionStatus, BreathPhase, SessionLoadState;

class BreathModuleStateChannel {
  final ModuleStateChannel _channel;
  final BreathModuleInstructionStream _instructionStream;
  final String _sessionId;
  final DateTime Function() _clock;

  bool _started = false;
  bool _ended = false;
  BreathSessionStatus? _previousStatus;
  BreathPhase? _previousPhase;
  int? _previousExerciseIndex;
  String? _moduleSessionId;
  ({BreathSessionState state, int offsetMs})? _pendingInstruction;

  final Stopwatch _stopwatch;
  DateTime? _originWallClock;

  late final StreamSubscription<BreathSessionState> _stateSub;
  late final StreamSubscription<ModuleState> _channelSub;
  late final StreamSubscription<ModuleStateEvent> _eventsSub;

  BreathModuleStateChannel({
    required ModuleStateChannel channel,
    required Stream<BreathSessionState> stateStream,
    required BreathModuleInstructionStream instructionStream,
    required String sessionId,
    Stopwatch Function() stopwatchFactory = Stopwatch.new,
    DateTime Function() clock = DateTime.now,
  })  : _channel = channel,
        _instructionStream = instructionStream,
        _sessionId = sessionId,
        _stopwatch = stopwatchFactory(),
        _clock = clock {
    _stateSub = stateStream.listen(_onState);
    _channelSub = channel.state.listen((moduleState) {
      _moduleSessionId = moduleState.moduleSessionId;
      final sessionId = moduleState.moduleSessionId;
      if (sessionId != null) _flushPending(sessionId);
    });
    _eventsSub = channel.events.listen((event) {
      if (event is ModuleSessionAbandoned) reset();
    });
  }

  String? get moduleSessionId => _moduleSessionId;

  void _onState(BreathSessionState state) {
    if (state.loadState != SessionLoadState.ready) return;
    _handleLifecycle(state);
    _handleInstruction(state);
    _previousStatus = state.status;
    _previousPhase = state.phase;
    _previousExerciseIndex = state.exerciseIndex;
  }

  void _emitMarker(String phaseName, int tickCount, int offsetMs) {
    final sessionId = _moduleSessionId;
    if (sessionId == null) {
      logPrint('[BreathModuleState] dropping $phaseName marker — no moduleSessionId yet [$_sessionId]');
      return;
    }
    _instructionStream.sendSample(sessionId, phaseName, tickCount, offsetMs, _wireTimestamp(offsetMs));
  }

  void _handleLifecycle(BreathSessionState state) {
    final status = state.status;
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
        _originWallClock = _clock();
        _channel.start(type: ActivityType.breath, refId: _sessionId, clientTimestampMs: _originWallClock!.millisecondsSinceEpoch);
        _started = true;
        _previousPhase = null;
        _previousExerciseIndex = null;
      } else {
        logPrint('[BreathModuleState] BreathModuleStateChannel: session resume [$_sessionId]');
        _channel.unpause();
        _emitMarker(state.phase.name, state.currentPhaseTotalDuration, _stopwatch.elapsedMilliseconds);
        _previousPhase = state.phase;
        _previousExerciseIndex = state.exerciseIndex;
      }
    } else if (wasActive && status == BreathSessionStatus.pause) {
      if (_started && !_ended) {
        logPrint('[BreathModuleState] BreathModuleStateChannel: session pause [$_sessionId]');
        _channel.pause();
        _emitMarker('pause', 0, _stopwatch.elapsedMilliseconds);
      }
    } else if (status == BreathSessionStatus.complete) {
      if (_started && !_ended) {
        logPrint('[BreathModuleState] session complete at offset=${_stopwatch.elapsedMilliseconds}ms — sending end [$_sessionId]');
        _channel.end(clientTimestampMs: _wireTimestamp(_stopwatch.elapsedMilliseconds));
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
    logPrint('[BreathModuleState] phase=${state.phase.name} ex=${state.exerciseIndex} offset=${offsetMs}ms tickCount=${state.currentPhaseTotalDuration} [$_sessionId]');
    _instructionStream.sendSample(sessionId, state.phase.name, state.currentPhaseTotalDuration, offsetMs, _wireTimestamp(offsetMs));
  }

  void _flushPending(String sessionId) {
    final pending = _pendingInstruction;
    if (pending == null) return;
    _pendingInstruction = null;
    _instructionStream.sendSample(sessionId, pending.state.phase.name, pending.state.currentPhaseTotalDuration, pending.offsetMs, _wireTimestamp(pending.offsetMs));
  }

  int _wireTimestamp(int offsetMs) =>
      (_originWallClock?.millisecondsSinceEpoch ?? _clock().millisecondsSinceEpoch) + offsetMs;

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
    _eventsSub.cancel();
  }
}
