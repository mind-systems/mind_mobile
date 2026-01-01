enum BreathShape { square, triangle, circle }
enum TriangleOrientation { up, down }

class BreathExercise {
  final int breathInDuration;
  final int holdInDuration;
  final int breathOutDuration;
  final int holdOutDuration;
  final int repeatCount;
  final int restDuration;

  BreathExercise({
    required this.breathInDuration,
    required this.holdInDuration,
    required this.breathOutDuration,
    required this.holdOutDuration,
    this.repeatCount = 1,
    this.restDuration = 0,
  });

  int get cycleDuration => breathInDuration + holdInDuration + breathOutDuration + holdOutDuration;

  BreathShape get shape {
    final hasHoldAfterIn = holdInDuration > 0;
    final hasHoldAfterOut = holdOutDuration > 0;

    if (!hasHoldAfterIn && !hasHoldAfterOut) {
      return BreathShape.circle;
    } else if (hasHoldAfterIn && hasHoldAfterOut) {
      return BreathShape.square;
    } else {
      return BreathShape.triangle;
    }
  }

  TriangleOrientation? get triangleOrientation {
    if (shape != BreathShape.triangle) return null;

    return holdInDuration > 0
        ? TriangleOrientation.up
        : TriangleOrientation.down;
  }
}
