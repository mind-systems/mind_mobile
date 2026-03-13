class ExerciseComplexityInput {
  final int cycleDuration;
  final int restDuration;
  final int repeatCount;

  const ExerciseComplexityInput({
    required this.cycleDuration,
    required this.restDuration,
    required this.repeatCount,
  });
}

double calculateComplexity(List<ExerciseComplexityInput> inputs) {
  double contribution = 0;
  double penalty = 0;

  for (int i = 0; i < inputs.length; i++) {
    final ex = inputs[i];
    final isRest = ex.cycleDuration == 0;

    if (isRest) {
      if (i > 0) penalty += ex.restDuration * 3;
    } else {
      contribution += ex.cycleDuration * ex.repeatCount;
      if (ex.restDuration > 0) {
        penalty += ex.restDuration * ex.repeatCount * 5;
      }
    }
  }

  return (contribution - penalty).clamp(0, double.infinity);
}
