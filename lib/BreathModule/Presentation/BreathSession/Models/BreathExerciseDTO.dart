import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathStepDTO.dart';

class BreathExerciseDTO {
  final List<BreathStepDTO> steps;
  final int restDuration;
  final int repeatCount;
  final SetShape? shape;

  const BreathExerciseDTO({
    required this.steps,
    required this.restDuration,
    required this.repeatCount,
    required this.shape,
  });

  bool get isRestOnly => steps.isEmpty && restDuration > 0;

  int get cycleDuration => steps.fold(0, (sum, step) => sum + step.duration);
}
