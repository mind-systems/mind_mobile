
import 'ExerciseEditCellModel.dart';

enum ConstructorMode { create, edit }

class BreathSessionConstructorState {
  final ConstructorMode mode;
  final String description;
  final bool shared;
  final List<ExerciseEditCellModel> exercises;

  const BreathSessionConstructorState({
    required this.mode,
    required this.description,
    required this.shared,
    required this.exercises,
  });

  factory BreathSessionConstructorState.initial({
    required ConstructorMode mode,
    String? description,
    bool? shared,
    List<ExerciseEditCellModel>? initialExercises,
  }) {
    return BreathSessionConstructorState(
      mode: mode,
      description: description ?? '',
      shared: shared ?? false,
      exercises: initialExercises ?? [],
    );
  }

  BreathSessionConstructorState copyWith({
    ConstructorMode? mode,
    String? description,
    bool? shared,
    List<ExerciseEditCellModel>? exercises,
  }) {
    return BreathSessionConstructorState(
      mode: mode ?? this.mode,
      description: description ?? this.description,
      shared: shared ?? this.shared,
      exercises: exercises ?? this.exercises,
    );
  }

  /// Есть ли хотя бы одно валидное упражнение
  bool get isValid =>
      exercises.any((e) => e.isValid) && description.trim().isNotEmpty;

  /// Общая длительность всей сессии
  int get totalDuration =>
      exercises.fold(0, (sum, e) => sum + e.totalDuration);
}
