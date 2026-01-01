import 'package:mind/BreathModule/Presentation/BreathViewModel.dart';

class BreathSessionState {
  final BreathSessionStatus status;
  final BreathPhase phase;
  /// Сколько тиков осталось до конца текущего шага
  final int remainingTicks;

  /// Прогресс фигуры 0..1 (только для breath)
  final double shapeProgress;

  const BreathSessionState({
    required this.status,
    required this.phase,
    required this.remainingTicks,
    required this.shapeProgress,
  });

  factory BreathSessionState.initial() => const BreathSessionState(
    status: BreathSessionStatus.breath,
    phase: BreathPhase.inhale,
    remainingTicks: 0,
    shapeProgress: 0.0,
  );
}
