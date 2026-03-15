import 'package:mind/BreathModule/Presentation/BreathSession/Models/SetShape.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionStateMachine.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/TimelineStep.dart';

enum BreathSessionStatus { pause, breath, rest, complete }
enum BreathPhase { inhale, hold, exhale, rest }
enum SessionLoadState { loading, ready, error }

class BreathSessionState {
  final SessionLoadState loadState;
  final BreathSessionStatus status;
  final BreathPhase phase;

  /// Индекс текущего упражнения в сессии
  final int exerciseIndex;

  /// Сколько тиков осталось до конца текущего шага
  final int remainingTicks;

  /// Интервал от предыдущего тика до текущего в миллисекундах
  final int currentIntervalMs;

  /// Список шагов в текущем упражнении
  final List<TimelineStep> timelineSteps;
  final String? activeStepId;

  final bool isStarred;
  final bool canStar;

  // Enriched fields (Phase 1)
  final ResetReason? resetReason;
  final int totalPhases;
  final int currentPhaseIndex;
  final int currentPhaseTotalDuration;
  final SetShape? currentExerciseShape;
  final SetShape? nextExerciseShape;

  const BreathSessionState({
    required this.loadState,
    required this.status,
    required this.phase,
    required this.exerciseIndex,
    required this.remainingTicks,
    required this.currentIntervalMs,
    this.timelineSteps = const [],
    this.activeStepId,
    this.isStarred = false,
    this.canStar = false,
    this.resetReason,
    this.totalPhases = 0,
    this.currentPhaseIndex = 0,
    this.currentPhaseTotalDuration = 0,
    this.currentExerciseShape,
    this.nextExerciseShape,
  });

  factory BreathSessionState.initial() => const BreathSessionState(
    loadState: SessionLoadState.loading,
    status: BreathSessionStatus.pause,
    phase: BreathPhase.inhale,
    exerciseIndex: 0,
    remainingTicks: 0,
    currentIntervalMs: -1,
    timelineSteps: [],
    activeStepId: null,
  );

  BreathSessionState copyWith({
    SessionLoadState? loadState,
    BreathSessionStatus? status,
    BreathPhase? phase,
    int? exerciseIndex,
    int? remainingTicks,
    int? currentIntervalMs,
    List<TimelineStep>? timelineSteps,
    String? activeStepId,
    bool? isStarred,
    bool? canStar,
    // Note: resetReason uses ?? so copyWith cannot clear it to null.
    // Use explicit field assignment when clearing is needed.
    ResetReason? resetReason,
    int? totalPhases,
    int? currentPhaseIndex,
    int? currentPhaseTotalDuration,
    SetShape? currentExerciseShape,
    SetShape? nextExerciseShape,
  }) {
    return BreathSessionState(
      loadState: loadState ?? this.loadState,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      remainingTicks: remainingTicks ?? this.remainingTicks,
      currentIntervalMs: currentIntervalMs ?? this.currentIntervalMs,
      timelineSteps: timelineSteps ?? this.timelineSteps,
      activeStepId: activeStepId ?? this.activeStepId,
      isStarred: isStarred ?? this.isStarred,
      canStar: canStar ?? this.canStar,
      resetReason: resetReason ?? this.resetReason,
      totalPhases: totalPhases ?? this.totalPhases,
      currentPhaseIndex: currentPhaseIndex ?? this.currentPhaseIndex,
      currentPhaseTotalDuration: currentPhaseTotalDuration ?? this.currentPhaseTotalDuration,
      currentExerciseShape: currentExerciseShape ?? this.currentExerciseShape,
      nextExerciseShape: nextExerciseShape ?? this.nextExerciseShape,
    );
  }
}
