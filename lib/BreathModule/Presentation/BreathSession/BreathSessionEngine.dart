// BreathModule/Presentation/BreathSession/BreathSessionEngine.dart

import 'dart:async';
import 'package:mind/BreathModule/ITickService.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathExerciseDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/TimelineStep.dart';

enum ResetReason { newCycle, rest, exerciseChange }

class BreathEngineState {
  final BreathSessionStatus status;
  final BreathPhase phase;
  final int exerciseIndex;
  final int remainingTicks;
  final String? activeStepId;
  final int currentIntervalMs;

  const BreathEngineState({
    required this.status,
    required this.phase,
    required this.exerciseIndex,
    required this.remainingTicks,
    required this.activeStepId,
    required this.currentIntervalMs,
  });

  BreathEngineState copyWith({
    BreathSessionStatus? status,
    BreathPhase? phase,
    int? exerciseIndex,
    int? remainingTicks,
    String? activeStepId,
    int? currentIntervalMs,
  }) {
    return BreathEngineState(
      status: status ?? this.status,
      phase: phase ?? this.phase,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      remainingTicks: remainingTicks ?? this.remainingTicks,
      activeStepId: activeStepId ?? this.activeStepId,
      currentIntervalMs: currentIntervalMs ?? this.currentIntervalMs,
    );
  }
}

class BreathSessionEngine {
  final BreathSessionDTO session;
  final ITickService tickService;

  // Внутренние счётчики
  int _exerciseIndex = 0;
  int _repeatCounter = 0;
  int _cycleTick = 0;

  StreamSubscription<TickData>? _tickSubscription;

  final _stateController = StreamController<BreathEngineState>.broadcast();
  Stream<BreathEngineState> get stateStream => _stateController.stream;

  final _resetController = StreamController<ResetReason>.broadcast();
  Stream<ResetReason> get resetStream => _resetController.stream;

  late BreathEngineState _state;
  BreathEngineState get currentState => _state;

  BreathExerciseDTO get currentExercise => session.exercises[_exerciseIndex];

  BreathSessionEngine({
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

  BreathEngineState _initialRestState() {
    return BreathEngineState(
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
    );
  }

  BreathEngineState _initialBreathState() {
    final stepData = _getCurrentStepData(0);
    return BreathEngineState(
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
    );
  }

  // ===== Public controls =====

  void pause() {
    if (_state.status == BreathSessionStatus.complete) return;
    _emit(_state.copyWith(status: BreathSessionStatus.pause));
  }

  void resume() {
    if (_state.status != BreathSessionStatus.pause) return;
    final wasResting = _state.phase == BreathPhase.rest;
    _emit(_state.copyWith(
      status: wasResting
          ? BreathSessionStatus.rest
          : BreathSessionStatus.breath,
    ));
  }

  void complete() {
    _emit(_state.copyWith(status: BreathSessionStatus.complete));
    _tickSubscription?.cancel();
    _resetController.close();
  }

  // ===== Tick =====

  void _onTick(TickData tickData) {
    _emit(_state.copyWith(currentIntervalMs: tickData.intervalMs));

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
    _emit(BreathEngineState(
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

    _emit(BreathEngineState(
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
    ));
  }

  // ===== Transitions =====

  void _startRest(int intervalMs) {
    _cycleTick = 0;
    _resetController.add(ResetReason.rest);

    _emit(BreathEngineState(
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
    ));
  }

  void _startNewCycle(int intervalMs) {
    _resetController.add(ResetReason.newCycle);
    final stepData = _getCurrentStepData(0);

    _emit(BreathEngineState(
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
    ));
  }

  void _advanceExercise(int intervalMs) {
    _exerciseIndex++;

    if (_exerciseIndex >= session.exercises.length) {
      complete();
      return;
    }

    _cycleTick = 0;
    _repeatCounter = 0;
    _resetController.add(ResetReason.exerciseChange);

    if (session.exercises[_exerciseIndex].isRestOnly) {
      _startRest(intervalMs);
    } else {
      _startNewCycle(intervalMs);
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

  // ===== Facade methods для VM =====

  ({BreathPhase phase, int remainingInPhase}) getCurrentPhaseInfo() {
    if (_state.status == BreathSessionStatus.complete) {
      return (phase: BreathPhase.rest, remainingInPhase: 0);
    }

    if (_state.status == BreathSessionStatus.rest || _state.phase == BreathPhase.rest) {
      final remaining = (currentExercise.restDuration - _cycleTick).clamp(0, currentExercise.restDuration);
      return (phase: BreathPhase.rest, remainingInPhase: remaining);
    }

    if (currentExercise.steps.isEmpty) {
      return (phase: BreathPhase.rest, remainingInPhase: 0);
    }

    int accumulated = 0;
    for (final step in currentExercise.steps) {
      if (_cycleTick < accumulated + step.duration) {
        return (
          phase: step.phase,
          remainingInPhase: (accumulated + step.duration) - _cycleTick,
        );
      }
      accumulated += step.duration;
    }

    return (phase: currentExercise.steps.last.phase, remainingInPhase: 0);
  }

  ({int totalPhases, int currentPhaseIndex}) getCurrentPhaseMeta() {
    if (currentExercise.steps.isEmpty) {
      return (totalPhases: 0, currentPhaseIndex: 0);
    }

    int accumulated = 0;
    for (int i = 0; i < currentExercise.steps.length; i++) {
      if (_cycleTick < accumulated + currentExercise.steps[i].duration) {
        return (totalPhases: currentExercise.steps.length, currentPhaseIndex: i);
      }
      accumulated += currentExercise.steps[i].duration;
    }

    return (totalPhases: currentExercise.steps.length, currentPhaseIndex: currentExercise.steps.length - 1);
  }

  BreathExerciseDTO? getNextExerciseWithShape() {
    if (currentExercise.steps.isNotEmpty) return currentExercise;

    for (int i = _exerciseIndex + 1; i < session.exercises.length; i++) {
      if (session.exercises[i].steps.isNotEmpty) return session.exercises[i];
    }

    return null;
  }

  ({BreathPhase phase, int duration})? getNextPhaseInfo() {
    if (_state.status == BreathSessionStatus.complete) return null;

    if (_state.status == BreathSessionStatus.breath) {
      int accumulated = 0;
      int currentStepIndex = -1;

      for (int i = 0; i < currentExercise.steps.length; i++) {
        if (_cycleTick < accumulated + currentExercise.steps[i].duration) {
          currentStepIndex = i;
          break;
        }
        accumulated += currentExercise.steps[i].duration;
      }

      if (currentStepIndex >= 0 && currentStepIndex < currentExercise.steps.length - 1) {
        final next = currentExercise.steps[currentStepIndex + 1];
        return (phase: next.phase, duration: next.duration);
      }

      if (_repeatCounter + 1 < currentExercise.repeatCount) {
        if (currentExercise.restDuration > 0) {
          return (phase: BreathPhase.rest, duration: currentExercise.restDuration);
        }
        final first = currentExercise.steps.first;
        return (phase: first.phase, duration: first.duration);
      }

      if (_exerciseIndex + 1 < session.exercises.length) {
        final next = session.exercises[_exerciseIndex + 1];
        if (next.isRestOnly) return (phase: BreathPhase.rest, duration: next.restDuration);
        if (next.steps.isNotEmpty) return (phase: next.steps.first.phase, duration: next.steps.first.duration);
      }

      return null;
    }

    if (_state.status == BreathSessionStatus.rest ||
        _state.status == BreathSessionStatus.pause) {
      if (_repeatCounter < currentExercise.repeatCount && currentExercise.steps.isNotEmpty) {
        final first = currentExercise.steps.first;
        return (phase: first.phase, duration: first.duration);
      }

      if (_exerciseIndex + 1 < session.exercises.length) {
        final next = session.exercises[_exerciseIndex + 1];
        if (next.steps.isNotEmpty) return (phase: next.steps.first.phase, duration: next.steps.first.duration);
      }
    }

    return null;
  }

  // ===== Internal =====

  void _emit(BreathEngineState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  void dispose() {
    _tickSubscription?.cancel();
    _stateController.close();
    if (!_resetController.isClosed) _resetController.close();
  }
}
