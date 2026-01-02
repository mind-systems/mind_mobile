enum BreathSessionStatus { pause, breath, rest, complete }
enum BreathPhase { inhale, hold, exhale, rest }

class BreathSessionState {
  final BreathSessionStatus status;
  final BreathPhase phase;

  /// Индекс текущего упражнения в сессии
  final int exerciseIndex;

  /// Сколько тиков осталось до конца текущего шага
  final int remainingTicks;

  /// Прогресс фигуры 0..1 (только для breath)
  final double shapeProgress;

  const BreathSessionState({
    required this.status,
    required this.phase,
    required this.exerciseIndex,
    required this.remainingTicks,
    required this.shapeProgress,
  });

  factory BreathSessionState.initial() => const BreathSessionState(
    status: BreathSessionStatus.breath,
    phase: BreathPhase.inhale,
    exerciseIndex: 0,
    remainingTicks: 0,
    shapeProgress: 0.0,
  );

  BreathSessionState copyWith({
    BreathSessionStatus? status,
    BreathPhase? phase,
    int? exerciseIndex,
    int? remainingTicks,
    double? shapeProgress,
  }) {
    return BreathSessionState(
      status: status ?? this.status,
      phase: phase ?? this.phase,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      remainingTicks: remainingTicks ?? this.remainingTicks,
      shapeProgress: shapeProgress ?? this.shapeProgress,
    );
  }
}