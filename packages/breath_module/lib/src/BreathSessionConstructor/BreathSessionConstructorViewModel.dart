import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'IBreathSessionConstructorCoordinator.dart';
import 'IBreathSessionConstructorService.dart';
import 'Models/BreathSessionConstructorDTO.dart';
import 'Models/BreathSessionConstructorState.dart';
import 'Models/ExerciseEditCellModel.dart';

final breathSessionConstructorProvider =
    NotifierProvider<BreathSessionConstructorViewModel, BreathSessionConstructorState>(
      () => throw UnimplementedError(
        'BreathSessionConstructorViewModel must be overridden via ProviderScope',
      ),
    );

class BreathSessionConstructorViewModel
    extends Notifier<BreathSessionConstructorState> {
  final IBreathSessionConstructorService service;
  final IBreathSessionConstructorCoordinator coordinator;

  BreathSessionConstructorViewModel({required this.service, required this.coordinator});

  @override
  BreathSessionConstructorState build() {
    final subscription = service.observeSessionExpiry().listen((_) {
      coordinator.dismiss();
    });
    ref.onDispose(() => subscription.cancel());

    return _initializeState(service);
  }

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
