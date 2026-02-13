import 'package:mind/BreathModule/Models/StepType.dart';

class ExerciseStep {
  final StepType type;
  final int duration;

  ExerciseStep({required this.type, required this.duration});

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'duration': duration,
    };
  }

  factory ExerciseStep.fromJson(Map<String, dynamic> json) {
    return ExerciseStep(
      type: StepType.values.byName(json['type'] as String),
      duration: json['duration'] as int,
    );
  }
}
