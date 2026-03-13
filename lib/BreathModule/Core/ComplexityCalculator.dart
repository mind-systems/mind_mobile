import 'package:mind/BreathModule/Models/ExerciseSet.dart';

double calculateComplexity(List<ExerciseSet> exercises) {
  double contribution = 0;
  double penalty = 0;

  for (int i = 0; i < exercises.length; i++) {
    final ex = exercises[i];
    final isRestSeparator = ex.steps.isEmpty;

    if (isRestSeparator) {
      if (i > 0) penalty += ex.restDuration * 3;
    } else {
      final cycleDuration = ex.steps.fold(0, (sum, s) => sum + s.duration);
      contribution += cycleDuration * ex.repeatCount;
      if (ex.restDuration > 0) {
        penalty += ex.restDuration * ex.repeatCount * 5;
      }
    }
  }

  return (contribution - penalty).clamp(0, double.infinity);
}
