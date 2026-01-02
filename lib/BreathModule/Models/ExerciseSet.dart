import 'package:mind/BreathModule/Models/ExerciseStep.dart';

enum SetShape { square, triangle, circle }
enum TriangleOrientation { up, down }

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

  SetShape get shape {
    if (steps.length == 2) {
      return SetShape.circle;
    } else if (steps.length == 3) {
      return SetShape.triangle;
    } else if (steps.length == 4) {
      return SetShape.square;
    } else {
      return SetShape.circle;
    }
  }

  TriangleOrientation get triangleOrientation {
    return steps.lastOrNull?.type == StepType.hold
        ? TriangleOrientation.up
        : TriangleOrientation.down;
  }
}
