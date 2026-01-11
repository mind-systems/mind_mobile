import 'package:mind/BreathModule/Models/ExerciseStep.dart';

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
  }) {
    return 'exerciseIndex:$exerciseIndex;repeatCounter:$repeatCounter;stepIndex:$stepIndex';
  }

  static TimelineStepType mapStepTypeToTimelineType(StepType type) {
    switch (type) {
      case StepType.inhale: return TimelineStepType.inhale;
      case StepType.hold: return TimelineStepType.hold;
      case StepType.exhale: return TimelineStepType.exhale;
    }
  }
}
