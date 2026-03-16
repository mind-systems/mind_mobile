import 'BreathExerciseDTO.dart';

class BreathSessionDTO {
  final String id;
  final String description;
  final bool isStarred;
  final bool canStar;
  final List<BreathExerciseDTO> exercises;

  const BreathSessionDTO({
    required this.id,
    required this.description,
    required this.isStarred,
    required this.canStar,
    required this.exercises,
  });
}
