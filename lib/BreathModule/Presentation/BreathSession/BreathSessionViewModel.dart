import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/ITickService.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionStateMachine.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/IBreathSessionService.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathExerciseDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/TimelineStep.dart';

final breathViewModelProvider =
    StateNotifierProvider<BreathViewModel, BreathSessionState>((ref) {
  throw UnimplementedError(
    'BreathViewModel должен быть передан через override в BreathModule',
  );
});

class BreathViewModel extends StateNotifier<BreathSessionState> {
  final ITickService tickService;
  final IBreathSessionService service;
  final String sessionId;

  BreathSessionStateMachine? _stateMachine;
  StreamSubscription<BreathSessionStateMachineState>? _stateMachineSubscription;
  StreamSubscription<ResetReason>? _resetProxySubscription;

  BreathSessionDTO? _sessionDTO;

  final _resetController = StreamController<ResetReason>.broadcast();

  BreathViewModel({
    required this.tickService,
    required this.service,
    required this.sessionId,
  }) : super(BreathSessionState.initial());

  // ===== Lifecycle =====

  Future<void> initState() async {
    try {
      final dto = await service.getSession(sessionId);
      _sessionDTO = dto;
      _setupEngine(dto);
    } catch (e) {
      state = state.copyWith(loadState: SessionLoadState.error);
    }
  }

  void _setupEngine(BreathSessionDTO dto) {
    _stateMachineSubscription?.cancel();
    _resetProxySubscription?.cancel();
    _stateMachine?.dispose();

    _stateMachine = BreathSessionStateMachine(session: dto, tickService: tickService);

    _resetProxySubscription = _stateMachine!.resetStream.listen(_resetController.add);
    _stateMachineSubscription = _stateMachine!.stateStream.listen(_onEngineState);

    final timelineSteps = _buildTimelineSteps(dto);

    state = state.copyWith(
      loadState: SessionLoadState.ready,
      timelineSteps: timelineSteps,
      status: _stateMachine!.currentState.status,
      phase: _stateMachine!.currentState.phase,
      exerciseIndex: _stateMachine!.currentState.exerciseIndex,
      remainingTicks: _stateMachine!.currentState.remainingTicks,
      activeStepId: _stateMachine!.currentState.activeStepId,
      currentIntervalMs: _stateMachine!.currentState.currentIntervalMs,
    );
  }

  void _onEngineState(BreathSessionStateMachineState engineState) {
    final previousActiveId = state.activeStepId;
    final newActiveId = engineState.activeStepId;
    final remaining = _stateMachine!.getCurrentPhaseInfo().remainingInPhase;

    List<TimelineStep> updatedSteps = state.timelineSteps;

    if (newActiveId != null) {
      final stepChanged = previousActiveId != newActiveId;
      updatedSteps = state.timelineSteps.map((step) {
        if (step.id == null) return step;
        if (step.id == newActiveId) return step.copyWith(duration: remaining);
        if (stepChanged && step.id == previousActiveId) return step.copyWith(duration: 0);
        return step;
      }).toList();
    }

    state = state.copyWith(
      status: engineState.status,
      phase: engineState.phase,
      exerciseIndex: engineState.exerciseIndex,
      remainingTicks: engineState.remainingTicks,
      activeStepId: engineState.activeStepId,
      currentIntervalMs: engineState.currentIntervalMs,
      timelineSteps: updatedSteps,
    );
  }

  // ===== Timeline =====

  List<TimelineStep> _buildTimelineSteps(BreathSessionDTO dto) {
    final steps = <TimelineStep>[];

    for (var exerciseIndex = 0; exerciseIndex < dto.exercises.length; exerciseIndex++) {
      final exercise = dto.exercises[exerciseIndex];

      if (exerciseIndex > 0) {
        steps.add(const TimelineStep.separator());
      }

      if (exercise.isRestOnly) {
        steps.add(TimelineStep.fromPhase(
          phase: BreathPhase.rest,
          duration: exercise.restDuration,
          id: TimelineStep.generateId(
            exerciseIndex: exerciseIndex,
            repeatCounter: 0,
            stepIndex: 0,
            phase: BreathPhase.rest,
          ),
        ));
        continue;
      }

      for (var repeatCounter = 0; repeatCounter < exercise.repeatCount; repeatCounter++) {
        for (var stepIndex = 0; stepIndex < exercise.steps.length; stepIndex++) {
          final step = exercise.steps[stepIndex];
          steps.add(TimelineStep.fromPhase(
            phase: step.phase,
            duration: step.duration,
            id: TimelineStep.generateId(
              exerciseIndex: exerciseIndex,
              repeatCounter: repeatCounter,
              stepIndex: stepIndex,
              phase: step.phase,
            ),
          ));
        }

        final isLastRepeat = repeatCounter == exercise.repeatCount - 1;
        if (!isLastRepeat && exercise.restDuration > 0) {
          steps.add(TimelineStep.fromPhase(
            phase: BreathPhase.rest,
            duration: exercise.restDuration,
            id: TimelineStep.generateId(
              exerciseIndex: exerciseIndex,
              repeatCounter: repeatCounter + 1,
              stepIndex: 0,
              phase: BreathPhase.rest,
            ),
          ));
        }
      }
    }

    return steps;
  }

  // ===== Public controls =====

  void pause() => _stateMachine?.pause();

  void resume() => _stateMachine?.resume();

  void complete() => _stateMachine?.complete();

  void restart() {
    if (_sessionDTO == null) return;
    _setupEngine(_sessionDTO!);
  }

  // ===== Facade =====

  Stream<void> get tickStream => tickService.tickStream.cast();

  Stream<ResetReason> get resetStream => _resetController.stream;

  BreathExerciseDTO get currentExercise => _stateMachine!.currentExercise;

  ({BreathPhase phase, int remainingInPhase}) getCurrentPhaseInfo() =>
      _stateMachine?.getCurrentPhaseInfo() ??
      (phase: BreathPhase.rest, remainingInPhase: 0);

  ({int totalPhases, int currentPhaseIndex}) getCurrentPhaseMeta() =>
      _stateMachine?.getCurrentPhaseMeta() ?? (totalPhases: 0, currentPhaseIndex: 0);

  BreathExerciseDTO? getNextExerciseWithShape() =>
      _stateMachine?.getNextExerciseWithShape();

  ({BreathPhase phase, int duration})? getNextPhaseInfo() =>
      _stateMachine?.getNextPhaseInfo();

  // ===== Dispose =====

  @override
  void dispose() {
    _stateMachineSubscription?.cancel();
    _resetProxySubscription?.cancel();
    _stateMachine?.dispose();
    _resetController.close();
    super.dispose();
  }
}
