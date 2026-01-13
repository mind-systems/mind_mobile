import 'ExerciseEditCellModel.dart';

enum ConstructorMode { create, edit }

class BreathSessionConstructorState {
  final ConstructorMode mode;
  final String? sessionId;
  final String userId;
  final String description;
  final bool shared;
  final List<ExerciseEditCellModel> exercises;

  const BreathSessionConstructorState({
    required this.mode,
    required this.sessionId,
    required this.userId,
    required this.description,
    required this.shared,
    required this.exercises,
  });

  factory BreathSessionConstructorState.initial({
    required ConstructorMode mode,
    required String userId,
    String? sessionId,
    String? description,
    bool? shared,
    List<ExerciseEditCellModel>? initialExercises,
  }) {
    return BreathSessionConstructorState(
      mode: mode,
      sessionId: mode == ConstructorMode.create ? null : sessionId,
      userId: userId,
      description: description ?? '',
      shared: shared ?? false,
      exercises: initialExercises ?? [],
    );
  }

  BreathSessionConstructorState copyWith({
    ConstructorMode? mode,
    String? sessionId,
    String? userId,
    String? description,
    bool? shared,
    List<ExerciseEditCellModel>? exercises,
  }) {
    return BreathSessionConstructorState(
      mode: mode ?? this.mode,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
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
