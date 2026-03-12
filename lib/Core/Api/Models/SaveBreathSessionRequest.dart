import 'package:mind/BreathModule/Models/ExerciseSet.dart';

class SaveBreathSessionRequest {
  final String description;
  final List<ExerciseSet> exercises;
  final bool shared;

  SaveBreathSessionRequest({
    required this.description,
    required this.exercises,
    required this.shared,
  });

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'shared': shared,
    };
  }
}
