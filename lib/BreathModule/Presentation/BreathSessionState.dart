enum BreathSessionStatus { pause, breath, rest, complete }
enum BreathPhase { inhale, hold, exhale, rest }

class BreathSessionState {
  final BreathSessionStatus status;
  final BreathPhase phase;

  /// Индекс текущего упражнения в сессии
  final int exerciseIndex;

  /// Сколько тиков осталось до конца текущего шага
  final int remainingTicks;

  /// Интервал от предыдущего тика до текущего в миллисекундах
  final int currentIntervalMs;

  const BreathSessionState({
    required this.status,
    required this.phase,
    required this.exerciseIndex,
    required this.remainingTicks,
    required this.currentIntervalMs,
  });

  factory BreathSessionState.initial() => const BreathSessionState(
    status: BreathSessionStatus.breath,
    phase: BreathPhase.inhale,
    exerciseIndex: 0,
    remainingTicks: 0,
    currentIntervalMs: -1,
  );

  BreathSessionState copyWith({
    BreathSessionStatus? status,
    BreathPhase? phase,
    int? exerciseIndex,
    int? remainingTicks,
    int? currentIntervalMs,
  }) {
    return BreathSessionState(
      status: status ?? this.status,
      phase: phase ?? this.phase,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      remainingTicks: remainingTicks ?? this.remainingTicks,
      currentIntervalMs: currentIntervalMs ?? this.currentIntervalMs,
    );
  }
}
