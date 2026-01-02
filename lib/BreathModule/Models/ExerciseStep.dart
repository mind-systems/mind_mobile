enum StepType { inhale, hold, exhale }

class ExerciseStep {
  final StepType type;
  final int duration;

  ExerciseStep({required this.type, required this.duration});
}
