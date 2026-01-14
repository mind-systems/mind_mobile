import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/IBreathSessionConstructorService.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/BreathSessionDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/BreathSessionConstructorState.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/ExerciseEditCellModel.dart';
import 'package:mind/BreathModule/Presentation/CommonModels/TickSource.dart';

final breathSessionConstructorProvider = StateNotifierProvider.autoDispose<BreathSessionConstructorViewModel, BreathSessionConstructorState>(
  (ref) {
    throw UnimplementedError('BreathSessionConstructorViewModel должен быть передан через override в роутере');
  },
);

class BreathSessionConstructorViewModel extends StateNotifier<BreathSessionConstructorState> {
  final IBreathSessionConstructorService service;

  BreathSessionConstructorViewModel({required this.service}) : super(_initializeState(service));

  // Приватный статический метод для инициализации State из сервиса
  static BreathSessionConstructorState _initializeState(
      IBreathSessionConstructorService service,
      ) {
    final dto = service.getInitialState();
    final mode = service.getInitialConstructorMode();

    return BreathSessionConstructorState.initial(
      mode: mode,
      description: dto.description,
      shared: dto.shared,
      tickSource: dto.tickSource,
      initialExercises: dto.exercises,
    );
  }

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

  void updateShared(bool shared) {
    state = state.copyWith(shared: shared);
  }

  void updateTickSource(TickSource source) {
    state = state.copyWith(tickSource: source);
  }

  // ===== Валидация =====

  bool get canSave => state.isValid;

  // ===== Вычисляемые значения =====

  int get totalSessionDuration => state.totalDuration;

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
  BreathSessionDTO _buildDTO() {
    return BreathSessionDTO(
      description: state.description.trim(),
      shared: state.shared,
      tickSource: state.tickSource,
      exercises: state.exercises
          .where((e) => e.isValid)
          .toList(),
    );
  }
}
