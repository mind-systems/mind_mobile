import 'package:mind/BreathModule/Models/ExerciseStep.dart';
import 'package:mind/BreathModule/Presentation/CommonModels/StepType.dart';

enum SetShape { square, triangleUp, triangleDown, circle }

class ExerciseSet {
  final List<ExerciseStep> steps;
  final int restDuration;

  final int repeatCount;

  ExerciseSet({
    required this.steps,
    this.restDuration = 0,
    this.repeatCount = 1,
  });

  int get cycleDuration => steps.fold(0, (sum, step) => sum + step.duration);

  SetShape? get shape {
    if (steps.length == 2) return SetShape.circle;
    if (steps.length == 3) return steps.last.type == StepType.hold ? SetShape.triangleUp : SetShape.triangleDown;
    if (steps.length == 4) return SetShape.square;
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'steps': steps.map((step) => step.toJson()).toList(),
      'restDuration': restDuration,
      'repeatCount': repeatCount,
    };
  }

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    return ExerciseSet(
      steps: (json['steps'] as List).map((step) => ExerciseStep.fromJson(step as Map<String, dynamic>)).toList(),
      restDuration: json['restDuration'] as int,
      repeatCount: json['repeatCount'] as int,
    );
  }
}
