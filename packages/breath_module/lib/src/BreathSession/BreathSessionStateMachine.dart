// BreathModule/Presentation/BreathSession/BreathSessionEngine.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../ITickService.dart';
import '../CommonModels/SetShape.dart';
import 'Models/BreathExerciseDTO.dart';
import 'Models/BreathSessionDTO.dart';
import 'Models/BreathSessionState.dart';
import 'Models/TimelineStep.dart';

class BreathSessionStateMachineState {
  final BreathSessionStatus status;
  final BreathPhase phase;
  final int exerciseIndex;
  final int remainingTicks;
  final String? activeStepId;
  final int currentIntervalMs;

  // Enriched fields (Phase 1)
  final ResetReason? resetReason;
  final int totalPhases;
  final int currentPhaseIndex;
  final int currentPhaseTotalDuration;
  final SetShape? currentExerciseShape;
  final SetShape? nextExerciseShape;

  const BreathSessionStateMachineState({
    required this.status,
    required this.phase,
    required this.exerciseIndex,
    required this.remainingTicks,
    required this.activeStepId,
    required this.currentIntervalMs,
    this.resetReason,
    this.totalPhases = 0,
    this.currentPhaseIndex = 0,
    this.currentPhaseTotalDuration = 0,
    this.currentExerciseShape,
    this.nextExerciseShape,
  });

  BreathSessionStateMachineState copyWith({
    BreathSessionStatus? status,
    BreathPhase? phase,
    int? exerciseIndex,
    int? remainingTicks,
    String? activeStepId,
    int? currentIntervalMs,
    ResetReason? resetReason,
    int? totalPhases,
    int? currentPhaseIndex,
    int? currentPhaseTotalDuration,
    SetShape? currentExerciseShape,
    SetShape? nextExerciseShape,
  }) {
    return BreathSessionStateMachineState(
      status: status ?? this.status,
      phase: phase ?? this.phase,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      remainingTicks: remainingTicks ?? this.remainingTicks,
      activeStepId: activeStepId ?? this.activeStepId,
      currentIntervalMs: currentIntervalMs ?? this.currentIntervalMs,
      resetReason: resetReason ?? this.resetReason,
      totalPhases: totalPhases ?? this.totalPhases,
      currentPhaseIndex: currentPhaseIndex ?? this.currentPhaseIndex,
      currentPhaseTotalDuration: currentPhaseTotalDuration ?? this.currentPhaseTotalDuration,
      currentExerciseShape: currentExerciseShape ?? this.currentExerciseShape,
      nextExerciseShape: nextExerciseShape ?? this.nextExerciseShape,
    );
  }
}

class BreathSessionStateMachine {
  final BreathSessionDTO session;
  final ITickService tickService;

  // Внутренние счётчики
  int _exerciseIndex = 0;
  int _repeatCounter = 0;
  int _cycleTick = 0;

  StreamSubscription<TickData>? _tickSubscription;

  final _stateController = StreamController<BreathSessionStateMachineState>.broadcast();
  Stream<BreathSessionStateMachineState> get stateStream => _stateController.stream;

  late BreathSessionStateMachineState _state;
  BreathSessionStateMachineState get currentState => _state;

  BreathExerciseDTO get currentExercise {
    final safeIndex = _exerciseIndex.clamp(0, session.exercises.length - 1);
    return session.exercises[safeIndex];
  }

  BreathSessionStateMachine({
    required this.session,
    required this.tickService,
  }) {
    final firstExercise = session.exercises[0];

    if (firstExercise.isRestOnly) {
      _state = _initialRestState();
    } else {
      _state = _initialBreathState();
    }

    _tickSubscription = tickService.tickStream.listen(_onTick);
  }

  // ===== Init =====

  BreathSessionStateMachineState _initialRestState() {
    final enriched = _computeEnrichedFields(0, isRest: true);
    return BreathSessionStateMachineState(
      status: BreathSessionStatus.pause,
      phase: BreathPhase.rest,
      exerciseIndex: _exerciseIndex,
      remainingTicks: currentExercise.restDuration,
      activeStepId: TimelineStep.generateId(
        exerciseIndex: _exerciseIndex,
        repeatCounter: 0,
        stepIndex: 0,
        phase: BreathPhase.rest,
      ),
      currentIntervalMs: -1,
      resetReason: null,
      totalPhases: enriched.totalPhases,
      currentPhaseIndex: enriched.currentPhaseIndex,
      currentPhaseTotalDuration: enriched.currentPhaseTotalDuration,
      currentExerciseShape: enriched.currentExerciseShape,
      nextExerciseShape: enriched.nextExerciseShape,
    );
  }

  BreathSessionStateMachineState _initialBreathState() {
    final stepData = _getCurrentStepData(0);
    final enriched = _computeEnrichedFields(stepData.stepIndex);
    return BreathSessionStateMachineState(
      status: BreathSessionStatus.pause,
      phase: stepData.phase,
      exerciseIndex: _exerciseIndex,
      remainingTicks: stepData.remainingTicks,
      activeStepId: TimelineStep.generateId(
        exerciseIndex: _exerciseIndex,
        repeatCounter: 0,
        stepIndex: 0,
        phase: stepData.phase,
      ),
      currentIntervalMs: -1,
      resetReason: null,
      totalPhases: enriched.totalPhases,
      currentPhaseIndex: enriched.currentPhaseIndex,
      currentPhaseTotalDuration: enriched.currentPhaseTotalDuration,
      currentExerciseShape: enriched.currentExerciseShape,
      nextExerciseShape: enriched.nextExerciseShape,
    );
  }

  // ===== Public controls =====

  void pause() {
    if (_state.status == BreathSessionStatus.complete) return;
    // Full constructor to clear resetReason (copyWith cannot set nullable to null).
    _emit(BreathSessionStateMachineState(
      status: BreathSessionStatus.pause,
      phase: _state.phase,
      exerciseIndex: _state.exerciseIndex,
      remainingTicks: _state.remainingTicks,
      activeStepId: _state.activeStepId,
      currentIntervalMs: _state.currentIntervalMs,
      resetReason: null,
      totalPhases: _state.totalPhases,
      currentPhaseIndex: _state.currentPhaseIndex,
      currentPhaseTotalDuration: _state.currentPhaseTotalDuration,
      currentExerciseShape: _state.currentExerciseShape,
      nextExerciseShape: _state.nextExerciseShape,
    ));
  }

  void resume() {
    if (_state.status != BreathSessionStatus.pause) return;
    final wasResting = _state.phase == BreathPhase.rest;
    // Full constructor to clear resetReason (copyWith cannot set nullable to null).
    _emit(BreathSessionStateMachineState(
      status: wasResting ? BreathSessionStatus.rest : BreathSessionStatus.breath,
      phase: _state.phase,
      exerciseIndex: _state.exerciseIndex,
      remainingTicks: _state.remainingTicks,
      activeStepId: _state.activeStepId,
      currentIntervalMs: _state.currentIntervalMs,
      resetReason: null,
      totalPhases: _state.totalPhases,
      currentPhaseIndex: _state.currentPhaseIndex,
      currentPhaseTotalDuration: _state.currentPhaseTotalDuration,
      currentExerciseShape: _state.currentExerciseShape,
      nextExerciseShape: _state.nextExerciseShape,
    ));
  }

  void complete() {
    // Full constructor to clear resetReason (copyWith cannot set nullable to null).
    _emit(BreathSessionStateMachineState(
      status: BreathSessionStatus.complete,
      phase: _state.phase,
      exerciseIndex: _state.exerciseIndex,
      remainingTicks: _state.remainingTicks,
      activeStepId: _state.activeStepId,
      currentIntervalMs: _state.currentIntervalMs,
      resetReason: null,
      totalPhases: _state.totalPhases,
      currentPhaseIndex: _state.currentPhaseIndex,
      currentPhaseTotalDuration: _state.currentPhaseTotalDuration,
      currentExerciseShape: _state.currentExerciseShape,
      nextExerciseShape: _state.nextExerciseShape,
    ));
    _tickSubscription?.cancel();
  }

  // ===== Tick =====

  void _onTick(TickData tickData) {
    // No first emit here — currentIntervalMs is folded into the single emit below.
    if (_state.status == BreathSessionStatus.pause ||
        _state.status == BreathSessionStatus.complete) {
      return;
    }

    switch (_state.status) {
      case BreathSessionStatus.breath:
        _onBreathTick(tickData.intervalMs);
        break;
      case BreathSessionStatus.rest:
        _onRestTick(tickData.intervalMs);
        break;
      default:
        break;
    }
  }

  void _onBreathTick(int intervalMs) {
    _cycleTick++;

    if (_cycleTick >= currentExercise.cycleDuration) {
      _cycleTick = 0;
      _repeatCounter++;

      if (_repeatCounter >= currentExercise.repeatCount) {
        _repeatCounter = 0;
        _advanceExercise(intervalMs);
        return;
      }

      if (currentExercise.restDuration > 0) {
        _startRest(intervalMs);
        return;
      }

      _startNewCycle(intervalMs);
      return;
    }

    final stepData = _getCurrentStepData(_cycleTick);
    final enriched = _computeEnrichedFields(stepData.stepIndex);
    _emit(BreathSessionStateMachineState(
      status: BreathSessionStatus.breath,
      phase: stepData.phase,
      exerciseIndex: _exerciseIndex,
      remainingTicks: stepData.remainingTicks,
      activeStepId: TimelineStep.generateId(
        exerciseIndex: _exerciseIndex,
        repeatCounter: _repeatCounter,
        stepIndex: stepData.stepIndex,
        phase: stepData.phase,
      ),
      currentIntervalMs: intervalMs,
      resetReason: null,
      totalPhases: enriched.totalPhases,
      currentPhaseIndex: enriched.currentPhaseIndex,
      currentPhaseTotalDuration: enriched.currentPhaseTotalDuration,
      currentExerciseShape: enriched.currentExerciseShape,
      nextExerciseShape: enriched.nextExerciseShape,
    ));
  }

  void _onRestTick(int intervalMs) {
    _cycleTick++;

    if (_cycleTick >= currentExercise.restDuration) {
      _cycleTick = 0;

      if (currentExercise.isRestOnly) {
        _advanceExercise(intervalMs);
        return;
      }

      _startNewCycle(intervalMs);
      return;
    }

    final enriched = _computeEnrichedFields(0, isRest: true);
    _emit(BreathSessionStateMachineState(
      status: BreathSessionStatus.rest,
      phase: BreathPhase.rest,
      exerciseIndex: _exerciseIndex,
      remainingTicks: currentExercise.restDuration - _cycleTick,
      activeStepId: TimelineStep.generateId(
        exerciseIndex: _exerciseIndex,
        repeatCounter: _repeatCounter,
        stepIndex: 0,
        phase: BreathPhase.rest,
      ),
      currentIntervalMs: intervalMs,
      resetReason: null,
      totalPhases: enriched.totalPhases,
      currentPhaseIndex: enriched.currentPhaseIndex,
      currentPhaseTotalDuration: enriched.currentPhaseTotalDuration,
      currentExerciseShape: enriched.currentExerciseShape,
      nextExerciseShape: enriched.nextExerciseShape,
    ));
  }

  // ===== Transitions =====

  void _startRest(int intervalMs, {bool isExerciseChange = false}) {
    _cycleTick = 0;
    final reason = isExerciseChange ? ResetReason.exerciseChange : ResetReason.rest;

    final enriched = _computeEnrichedFields(0, isRest: true);
    _emit(BreathSessionStateMachineState(
      status: BreathSessionStatus.rest,
      phase: BreathPhase.rest,
      exerciseIndex: _exerciseIndex,
      remainingTicks: currentExercise.restDuration,
      activeStepId: TimelineStep.generateId(
        exerciseIndex: _exerciseIndex,
        repeatCounter: _repeatCounter,
        stepIndex: 0,
        phase: BreathPhase.rest,
      ),
      currentIntervalMs: intervalMs,
      resetReason: reason,
      totalPhases: enriched.totalPhases,
      currentPhaseIndex: enriched.currentPhaseIndex,
      currentPhaseTotalDuration: enriched.currentPhaseTotalDuration,
      currentExerciseShape: enriched.currentExerciseShape,
      nextExerciseShape: enriched.nextExerciseShape,
    ));

    if (kDebugMode) {
      debugPrint('[SM] transition: $reason, exercise: $_exerciseIndex');
    }
  }

  void _startNewCycle(int intervalMs, {bool isExerciseChange = false}) {
    final reason = isExerciseChange ? ResetReason.exerciseChange : ResetReason.newCycle;
    final stepData = _getCurrentStepData(0);
    final enriched = _computeEnrichedFields(stepData.stepIndex);

    _emit(BreathSessionStateMachineState(
      status: BreathSessionStatus.breath,
      phase: stepData.phase,
      exerciseIndex: _exerciseIndex,
      remainingTicks: stepData.remainingTicks,
      activeStepId: TimelineStep.generateId(
        exerciseIndex: _exerciseIndex,
        repeatCounter: _repeatCounter,
        stepIndex: stepData.stepIndex,
        phase: stepData.phase,
      ),
      currentIntervalMs: intervalMs,
      resetReason: reason,
      totalPhases: enriched.totalPhases,
      currentPhaseIndex: enriched.currentPhaseIndex,
      currentPhaseTotalDuration: enriched.currentPhaseTotalDuration,
      currentExerciseShape: enriched.currentExerciseShape,
      nextExerciseShape: enriched.nextExerciseShape,
    ));

    if (kDebugMode) {
      debugPrint('[SM] transition: $reason, exercise: $_exerciseIndex');
    }
  }

  void _advanceExercise(int intervalMs) {
    _exerciseIndex++;

    if (_exerciseIndex >= session.exercises.length) {
      _exerciseIndex = session.exercises.length - 1;
      complete();
      return;
    }

    _cycleTick = 0;
    _repeatCounter = 0;

    if (session.exercises[_exerciseIndex].isRestOnly) {
      _startRest(intervalMs, isExerciseChange: true);
    } else {
      _startNewCycle(intervalMs, isExerciseChange: true);
    }
  }

  // ===== Step calculation =====

  ({BreathPhase phase, int remainingTicks, int stepIndex}) _getCurrentStepData(int tick) {
    int accumulated = 0;

    for (int i = 0; i < currentExercise.steps.length; i++) {
      final step = currentExercise.steps[i];
      if (tick < accumulated + step.duration) {
        return (
          phase: step.phase,
          remainingTicks: (accumulated + step.duration) - tick,
          stepIndex: i,
        );
      }
      accumulated += step.duration;
    }

    final lastStep = currentExercise.steps.last;
    return (
      phase: lastStep.phase,
      remainingTicks: 0,
      stepIndex: currentExercise.steps.length - 1,
    );
  }

  // ===== Enriched field computation =====

  ({int totalPhases, int currentPhaseIndex, int currentPhaseTotalDuration,
    SetShape? currentExerciseShape, SetShape? nextExerciseShape})
      _computeEnrichedFields(int stepIndex, {bool isRest = false}) {
    final steps = currentExercise.steps;
    final totalPhases = steps.length;
    final currentPhaseIndex = stepIndex.clamp(0, totalPhases > 0 ? totalPhases - 1 : 0);
    final currentPhaseTotalDuration = isRest
        ? currentExercise.restDuration
        : steps.isNotEmpty
            ? steps[currentPhaseIndex].duration
            : currentExercise.restDuration;

    final currentExerciseShape = currentExercise.shape;

    SetShape? nextExerciseShape;
    if (steps.isNotEmpty) {
      nextExerciseShape = currentExercise.shape;
    } else {
      for (int i = _exerciseIndex + 1; i < session.exercises.length; i++) {
        if (session.exercises[i].steps.isNotEmpty) {
          nextExerciseShape = session.exercises[i].shape;
          break;
        }
      }
    }

    return (
      totalPhases: totalPhases,
      currentPhaseIndex: currentPhaseIndex,
      currentPhaseTotalDuration: currentPhaseTotalDuration,
      currentExerciseShape: currentExerciseShape,
      nextExerciseShape: nextExerciseShape,
    );
  }

  // ===== Internal =====

  void _emit(BreathSessionStateMachineState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  void dispose() {
    _tickSubscription?.cancel();
    _stateController.close();
  }
}
