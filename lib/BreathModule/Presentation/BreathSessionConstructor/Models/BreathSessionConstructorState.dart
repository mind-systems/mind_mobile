import 'ExerciseEditCellModel.dart';

class BreathSessionConstructorState {
  final List<ExerciseEditCellModel> exercises;

  const BreathSessionConstructorState({
    required this.exercises,
  });

  factory BreathSessionConstructorState.initial({
    List<ExerciseEditCellModel>? initialExercises,
  }) {
    return BreathSessionConstructorState(
      exercises: initialExercises ?? [],
    );
  }

  BreathSessionConstructorState copyWith({
    List<ExerciseEditCellModel>? exercises,
  }) {
    return BreathSessionConstructorState(
      exercises: exercises ?? this.exercises,
    );
  }

  /// Есть ли хотя бы одно валидное упражнение
  bool get isValid =>
      exercises.any((e) => e.isValid);

  /// Общая длительность всей сессии
  int get totalDuration =>
      exercises.fold(0, (sum, e) => sum + e.totalDuration);
}
