import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/IBreathSessionConstructorService.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/BreathSessionConstructorDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/BreathSessionConstructorState.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/ExerciseEditCellModel.dart';

final breathSessionConstructorProvider =
    StateNotifierProvider.autoDispose<
      BreathSessionConstructorViewModel,
      BreathSessionConstructorState
    >((ref) {
      throw UnimplementedError(
        'BreathSessionConstructorViewModel должен быть передан через override в роутере',
      );
    });

class BreathSessionConstructorViewModel
    extends StateNotifier<BreathSessionConstructorState> {
  final IBreathSessionConstructorService service;

  BreathSessionConstructorViewModel({required this.service})
    : super(_initializeState(service));

  // Приватный статический метод для инициализации State из сервиса
  static BreathSessionConstructorState _initializeState(
    IBreathSessionConstructorService service,
  ) {
    final dto = service.getInitialState();
    final mode = service.getInitialConstructorMode();
    final exercises = dto.exercises;

    return BreathSessionConstructorState.initial(
      mode: mode,
      description: dto.description,
      shared: dto.shared,
      initialExercises: exercises,
      complexity: service.computeComplexity(exercises),
    );
  }

  // ===== CRUD упражнений =====

  void addExercise() {
    final newExercises = [...state.exercises, ExerciseEditCellModel.create()];
    state = state.copyWith(
      exercises: newExercises,
      complexity: service.computeComplexity(newExercises),
    );
  }

  void removeExercise(String id) {
    final newExercises = state.exercises.where((e) => e.id != id).toList();
    state = state.copyWith(
      exercises: newExercises,
      complexity: service.computeComplexity(newExercises),
    );
  }

  void updateExercise(String id, ExerciseEditCellModel updated) {
    final newExercises = state.exercises.map((e) => e.id == id ? updated : e).toList();
    state = state.copyWith(
      exercises: newExercises,
      complexity: service.computeComplexity(newExercises),
    );
  }

  // ===== Редактирование метаданных =====

  void updateDescription(String description) {
    state = state.copyWith(description: description);
  }

  void updateShared(bool shared) {
    state = state.copyWith(shared: shared);
  }

  // ===== Валидация =====

  bool get canSave => state.isValid;

  // ===== Вычисляемые значения =====

  int get totalSessionDuration => state.totalDuration;

  double get complexity => state.complexity;

  // ===== Работа с сервисом =====

  /// Сохранить текущий draft
  Future<void> save() async {
    if (!canSave) return;

    final dto = _buildDTO();
    await service.save(dto);
    // Навигация/закрытие экрана — ответственность UI
  }

  /// Удалить сессию (только в режиме edit)
  Future<void> delete() async {
    if (state.mode != ConstructorMode.edit) return;

    await service.delete();
    // Навигация/закрытие экрана — ответственность UI
  }

  /// Собрать DTO из текущего состояния (приватный метод)
  BreathSessionConstructorDTO _buildDTO() {
    return BreathSessionConstructorDTO(
      description: state.description.trim(),
      shared: state.shared,
      exercises: state.exercises.where((e) => e.isValid).toList(),
    );
  }
}
