import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/ITickService.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionEngine.dart';
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

  BreathSessionEngine? _engine;
  StreamSubscription<BreathEngineState>? _engineSubscription;

  BreathViewModel({
    required this.tickService,
    required this.service,
    required this.sessionId,
  }) : super(BreathSessionState.initial());

  // ===== Lifecycle =====

  Future<void> initState() async {
    try {
      final dto = await service.getSession(sessionId);

      _engine = BreathSessionEngine(
        session: dto,
        tickService: tickService,
      );

      _engineSubscription = _engine!.stateStream.listen(_onEngineState);

      final timelineSteps = _buildTimelineSteps(dto);

      state = state.copyWith(
        loadState: SessionLoadState.ready,
        timelineSteps: timelineSteps,
        status: _engine!.currentState.status,
        phase: _engine!.currentState.phase,
        exerciseIndex: _engine!.currentState.exerciseIndex,
        remainingTicks: _engine!.currentState.remainingTicks,
        activeStepId: _engine!.currentState.activeStepId,
        currentIntervalMs: _engine!.currentState.currentIntervalMs,
      );
    } catch (e) {
      state = state.copyWith(loadState: SessionLoadState.error);
    }
  }

  void _onEngineState(BreathEngineState engineState) {
    final previousActiveId = state.activeStepId;
    final newActiveId = engineState.activeStepId;
    final remaining = _engine!.getCurrentPhaseInfo().remainingInPhase;

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

  void pause() => _engine?.pause();

  void resume() => _engine?.resume();

  void complete() => _engine?.complete();

  // ===== Facade =====

  Stream<ResetReason> get resetStream =>
      _engine?.resetStream ?? const Stream.empty();

  BreathExerciseDTO get currentExercise => _engine!.currentExercise;

  ({BreathPhase phase, int remainingInPhase}) getCurrentPhaseInfo() =>
      _engine?.getCurrentPhaseInfo() ??
      (phase: BreathPhase.rest, remainingInPhase: 0);

  ({int totalPhases, int currentPhaseIndex}) getCurrentPhaseMeta() =>
      _engine?.getCurrentPhaseMeta() ??
      (totalPhases: 0, currentPhaseIndex: 0);

  BreathExerciseDTO? getNextExerciseWithShape() =>
      _engine?.getNextExerciseWithShape();

  ({BreathPhase phase, int duration})? getNextPhaseInfo() =>
      _engine?.getNextPhaseInfo();

  // ===== Dispose =====

  @override
  void dispose() {
    _engineSubscription?.cancel();
    _engine?.dispose();
    super.dispose();
  }
}
