import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/CommonModels/StepType.dart';

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

  /// Генерирует уникальный ID для шага timeline
  /// Separator не имеет ID (id = null)
  static String generateId({
    required int exerciseIndex,
    required int repeatCounter,
    required int stepIndex,
    required TimelineStepType type,
  }) {
    return 'exerciseIndex:$exerciseIndex;repeatCounter:$repeatCounter;stepIndex:$stepIndex;type:$type';
  }

  static TimelineStepType mapStepTypeToTimelineType(StepType type) {
    switch (type) {
      case StepType.inhale: return TimelineStepType.inhale;
      case StepType.hold: return TimelineStepType.hold;
      case StepType.exhale: return TimelineStepType.exhale;
    }
  }

  static TimelineStepType mapBreathPhaseToTimelineType(BreathPhase phase) {
    switch (phase) {
      case BreathPhase.inhale: return TimelineStepType.inhale;
      case BreathPhase.hold: return TimelineStepType.hold;
      case BreathPhase.exhale: return TimelineStepType.exhale;
      case BreathPhase.rest: return TimelineStepType.rest;
    }
  }
}
