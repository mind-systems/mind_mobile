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

  const BreathSessionState({
    required this.loadState,
    required this.status,
    required this.phase,
    required this.exerciseIndex,
    required this.remainingTicks,
    required this.currentIntervalMs,
    this.timelineSteps = const [],
    this.activeStepId,
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
    );
  }
}
