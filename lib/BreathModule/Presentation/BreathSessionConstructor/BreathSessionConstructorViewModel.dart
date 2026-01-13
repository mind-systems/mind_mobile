import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/BreathSessionConstructorState.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/ExerciseEditCellModel.dart';

final breathSessionConstructorProvider =
    StateNotifierProvider.autoDispose<BreathSessionConstructorViewModel, BreathSessionConstructorState>(
  (ref) {
    throw UnimplementedError(
      'BreathSessionConstructorViewModel должен быть передан через override в BreathModule',
    );
  },
);

class BreathSessionConstructorViewModel extends StateNotifier<BreathSessionConstructorState> {
  BreathSessionConstructorViewModel({
    required String currentUserId,
    required ConstructorMode mode,
    required BreathSession initialSession,
  }) : super(
          BreathSessionConstructorState.initial(
            mode: mode,
            userId: currentUserId,
            sessionId: mode == ConstructorMode.edit ? initialSession.id : null,
            description: initialSession.description,
            shared: mode == ConstructorMode.create ? false : initialSession.shared,
            initialExercises: initialSession.exercises
                .map((set) => ExerciseEditCellModel.fromExerciseSet(set))
                .toList(),
          ),
        );

  // ===== CRUD упражнений =====

  void addExercise() {
    state = state.copyWith(
      exercises: [
        ...state.exercises,
        ExerciseEditCellModel.create(),
      ],
    );
  }

  void removeExercise(String id) {
    state = state.copyWith(
      exercises: state.exercises.where((e) => e.id != id).toList(),
    );
  }

  void updateExercise(String id, ExerciseEditCellModel updated) {
    state = state.copyWith(
      exercises: state.exercises
          .map((e) => e.id == id ? updated : e)
          .toList(),
    );
  }

  // ===== Редактирование метаданных =====

  void updateDescription(String description) {
    state = state.copyWith(description: description);
  }

  // ===== Валидация =====

  bool get canSave => state.isValid;

  // ===== Вычисляемые значения =====

  int get totalSessionDuration {
    return state.exercises
        .where((e) => e.isValid)
        .fold(0, (sum, e) => sum + e.totalDuration);
  }

  // ===== Сборка BreathSession =====

  BreathSession buildSession({required TickSource tickSource}) {
    final sets = state.exercises
        .where((e) => e.isValid)
        .map((e) => e.toExerciseSet())
        .toList();

    final sessionId = state.sessionId ?? const Uuid().v4();
    final shared = state.mode == ConstructorMode.create ? false : state.shared;

    return BreathSession(
      id: sessionId,
      userId: state.userId,
      description: state.description.trim(),
      shared: shared,
      exercises: sets,
      tickSource: tickSource,
    );
  }
}
