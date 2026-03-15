import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/ITickService.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionStateMachine.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/IBreathSessionCoordinator.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/IBreathSessionService.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/TimelineStep.dart';

enum BreathSessionError { starFailed }

final breathViewModelProvider =
    StateNotifierProvider<BreathViewModel, BreathSessionState>((ref) {
  throw UnimplementedError(
    'BreathViewModel должен быть передан через override в BreathModule',
  );
});

class BreathViewModel extends StateNotifier<BreathSessionState> {
  final ITickService tickService;
  final IBreathSessionService service;
  final IBreathSessionCoordinator coordinator;
  final String sessionId;

  BreathSessionStateMachine? _stateMachine;
  StreamSubscription<BreathSessionStateMachineState>? _stateMachineSubscription;

  void Function(BreathSessionError error)? onErrorEvent;

  BreathSessionDTO? _sessionDTO;

  BreathViewModel({
    required this.tickService,
    required this.service,
    required this.coordinator,
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
    _stateMachine?.dispose();

    _stateMachine = BreathSessionStateMachine(session: dto, tickService: tickService);

    _stateMachineSubscription = _stateMachine!.stateStream.listen(_onEngineState);

    final timelineSteps = _buildTimelineSteps(dto);

    final initialEngineState = _stateMachine!.currentState;
    // Full constructor — copyWith cannot clear nullable fields on restart
    // (e.g. stale currentExerciseShape from previous session).
    state = BreathSessionState(
      loadState: SessionLoadState.ready,
      timelineSteps: timelineSteps,
      status: initialEngineState.status,
      phase: initialEngineState.phase,
      exerciseIndex: initialEngineState.exerciseIndex,
      remainingTicks: initialEngineState.remainingTicks,
      activeStepId: initialEngineState.activeStepId,
      currentIntervalMs: initialEngineState.currentIntervalMs,
      isStarred: dto.isStarred,
      canStar: dto.canStar,
      resetReason: initialEngineState.resetReason,
      totalPhases: initialEngineState.totalPhases,
      currentPhaseIndex: initialEngineState.currentPhaseIndex,
      currentPhaseTotalDuration: initialEngineState.currentPhaseTotalDuration,
      currentExerciseShape: initialEngineState.currentExerciseShape,
      nextExerciseShape: initialEngineState.nextExerciseShape,
    );
  }

  void _onEngineState(BreathSessionStateMachineState engineState) {
    final previousActiveId = state.activeStepId;
    final newActiveId = engineState.activeStepId;
    final remaining = engineState.remainingTicks;

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

    // Full constructor — copyWith cannot clear nullable fields (resetReason,
    // currentExerciseShape, nextExerciseShape) when the engine emits null.
    state = BreathSessionState(
      loadState: state.loadState,
      status: engineState.status,
      phase: engineState.phase,
      exerciseIndex: engineState.exerciseIndex,
      remainingTicks: engineState.remainingTicks,
      activeStepId: engineState.activeStepId,
      currentIntervalMs: engineState.currentIntervalMs,
      timelineSteps: updatedSteps,
      isStarred: state.isStarred,
      canStar: state.canStar,
      resetReason: engineState.resetReason,
      totalPhases: engineState.totalPhases,
      currentPhaseIndex: engineState.currentPhaseIndex,
      currentPhaseTotalDuration: engineState.currentPhaseTotalDuration,
      currentExerciseShape: engineState.currentExerciseShape,
      nextExerciseShape: engineState.nextExerciseShape,
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

  Stream<void> get tickStream => tickService.tickStream.cast();

  void pause() => _stateMachine?.pause();

  void resume() => _stateMachine?.resume();

  void complete() => _stateMachine?.complete();

  void restartEngine() {
    if (_sessionDTO == null) return;
    _setupEngine(_sessionDTO!);
  }

  void openEditor() {
    if (_sessionDTO == null) return;
    pause();
    coordinator.openConstructor(sessionId);
  }

  void shareSession() => coordinator.shareSession(sessionId);

  Future<void> toggleStar() async {
    final newStarred = !state.isStarred;
    state = state.copyWith(isStarred: newStarred);
    try {
      final dto = await service.starSession(sessionId, starred: newStarred);
      _sessionDTO = dto;
      state = state.copyWith(isStarred: dto.isStarred);
    } catch (_) {
      state = state.copyWith(isStarred: !newStarred);
      onErrorEvent?.call(BreathSessionError.starFailed);
    }
  }

  // ===== Dispose =====

  @override
  void dispose() {
    _stateMachineSubscription?.cancel();
    _stateMachine?.dispose();
    super.dispose();
  }
}
