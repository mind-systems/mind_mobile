
import 'ExerciseEditCellModel.dart';

enum ConstructorMode { create, edit }

class BreathSessionConstructorState {
  final ConstructorMode mode;
  final String description;
  final bool shared;
  final List<ExerciseEditCellModel> exercises;
  final double complexity;

  const BreathSessionConstructorState({
    required this.mode,
    required this.description,
    required this.shared,
    required this.exercises,
    this.complexity = 0.0,
  });

  factory BreathSessionConstructorState.initial({
    required ConstructorMode mode,
    String? description,
    bool? shared,
    List<ExerciseEditCellModel>? initialExercises,
    double complexity = 0.0,
  }) {
    return BreathSessionConstructorState(
      mode: mode,
      description: description ?? '',
      shared: shared ?? false,
      exercises: initialExercises ?? [],
      complexity: complexity,
    );
  }

  BreathSessionConstructorState copyWith({
    ConstructorMode? mode,
    String? description,
    bool? shared,
    List<ExerciseEditCellModel>? exercises,
    double? complexity,
  }) {
    return BreathSessionConstructorState(
      mode: mode ?? this.mode,
      description: description ?? this.description,
      shared: shared ?? this.shared,
      exercises: exercises ?? this.exercises,
      complexity: complexity ?? this.complexity,
    );
  }

  /// Есть ли хотя бы одно валидное упражнение
  bool get isValid =>
      exercises.any((e) => e.isValid) && description.trim().isNotEmpty;

  /// Общая длительность всей сессии
  int get totalDuration =>
      exercises.fold(0, (sum, e) => sum + e.totalDuration);
}
