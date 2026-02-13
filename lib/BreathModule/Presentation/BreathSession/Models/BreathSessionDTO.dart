import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathExerciseDTO.dart';

class BreathSessionDTO {
  final String id;
  final String description;
  final List<BreathExerciseDTO> exercises;

  const BreathSessionDTO({
    required this.id,
    required this.description,
    required this.exercises,
  });
}
