class BreathSessionListItemDTO {
  final String id;
  final String description;
  final List<BreathPatternDTO> patterns;
  final int totalDurationSeconds;

  const BreathSessionListItemDTO({
    required this.id,
    required this.description,
    required this.patterns,
    required this.totalDurationSeconds,
  });
}

class BreathPatternDTO {
  final BreathPatternShape shape;
  final List<int> durations;
  final int repeatCount;

  const BreathPatternDTO({
    required this.shape,
    required this.durations,
    required this.repeatCount,
  });
}

enum BreathPatternShape {
  circle,
  square,
  triangleUp,
  triangleDown,
}
