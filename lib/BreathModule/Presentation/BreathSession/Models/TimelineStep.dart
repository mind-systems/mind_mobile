import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';

enum TimelineStepType { inhale, hold, exhale, rest, separator }

class TimelineStep {
  final String? id; // unique identifier for step matching
  final TimelineStepType type;
  final int? duration; // null for separator

  const TimelineStep({
    this.id,
    required this.type,
    this.duration,
  });

  const TimelineStep.separator() : id = null, type = TimelineStepType.separator, duration = null;

  /// Создаёт TimelineStep из BreathPhase
  factory TimelineStep.fromPhase({
    required BreathPhase phase,
    required int duration,
    required String id,
  }) {
    return TimelineStep(
      id: id,
      type: _mapPhaseToType(phase),
      duration: duration,
    );
  }

  /// Генерирует уникальный ID для шага timeline
  static String generateId({
    required int exerciseIndex,
    required int repeatCounter,
    required int stepIndex,
    required BreathPhase phase,
  }) {
    return 'exerciseIndex:$exerciseIndex;repeatCounter:$repeatCounter;stepIndex:$stepIndex;type:${_mapPhaseToType(phase)}';
  }

  TimelineStep copyWith({int? duration}) {
    return TimelineStep(
      id: id,
      type: type,
      duration: duration ?? this.duration,
    );
  }

  static TimelineStepType _mapPhaseToType(BreathPhase phase) {
    switch (phase) {
      case BreathPhase.inhale: return TimelineStepType.inhale;
      case BreathPhase.hold: return TimelineStepType.hold;
      case BreathPhase.exhale: return TimelineStepType.exhale;
      case BreathPhase.rest: return TimelineStepType.rest;
    }
  }
}
