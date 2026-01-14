import 'package:mind/BreathModule/Presentation/CommonModels/TickSource.dart';

import 'ExerciseEditCellModel.dart';

enum ConstructorMode { create, edit }

class BreathSessionConstructorState {
  final ConstructorMode mode;
  final String description;
  final bool shared;
  final TickSource tickSource;
  final List<ExerciseEditCellModel> exercises;

  const BreathSessionConstructorState({
    required this.mode,
    required this.description,
    required this.shared,
    required this.tickSource,
    required this.exercises,
  });

  factory BreathSessionConstructorState.initial({
    required ConstructorMode mode,
    String? description,
    bool? shared,
    TickSource? tickSource,
    List<ExerciseEditCellModel>? initialExercises,
  }) {
    return BreathSessionConstructorState(
      mode: mode,
      description: description ?? '',
      shared: shared ?? false,
      tickSource: tickSource ?? TickSource.timer,
      exercises: initialExercises ?? [],
    );
  }

  BreathSessionConstructorState copyWith({
    ConstructorMode? mode,
    String? sessionId,
    String? userId,
    String? description,
    bool? shared,
    TickSource? tickSource,
    List<ExerciseEditCellModel>? exercises,
  }) {
    return BreathSessionConstructorState(
      mode: mode ?? this.mode,
      description: description ?? this.description,
      shared: shared ?? this.shared,
      tickSource: tickSource ?? this.tickSource,
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
