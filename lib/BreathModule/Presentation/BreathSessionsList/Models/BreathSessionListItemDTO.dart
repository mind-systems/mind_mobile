import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListItem.dart';

class BreathSessionListItemDTO {
  final String id;
  final String description;
  final List<BreathPatternDTO> patterns;
  final int totalDurationSeconds;
  final SessionOwnership ownership;

  const BreathSessionListItemDTO({
    required this.id,
    required this.description,
    required this.patterns,
    required this.totalDurationSeconds,
    required this.ownership,
  });
}

class BreathPatternDTO {
  final BreathPatternShape shape;
  final List<int> durations;
  final int repeatCount;

  final bool isRestOnly;

  const BreathPatternDTO({
    required this.shape,
    required this.durations,
    required this.repeatCount,
    required this.isRestOnly,
  });
}

enum BreathPatternShape {
  circle,
  square,
  triangleUp,
  triangleDown,
}
