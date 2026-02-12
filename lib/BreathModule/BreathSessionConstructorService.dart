import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Models/ExerciseStep.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/IBreathSessionConstructorService.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/BreathSessionConstructorState.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/BreathSessionConstructorDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/ExerciseEditCellModel.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Presentation/CommonModels/StepType.dart';
import 'package:uuid/uuid.dart';

class BreathSessionConstructorService implements IBreathSessionConstructorService {
  final String userId;
  final BreathSession? existingSession;
  final BreathSessionNotifier provider;

  BreathSessionConstructorService({
    required this.userId,
    required this.existingSession,
    required this.provider,
  });

  @override
  BreathSessionDTO getInitialState() {
    // Если сессии нет — возвращаем пустой DTO для создания
    if (existingSession == null) {
      return BreathSessionDTO.empty();
    }

    // Если есть — конвертируем в DTO для редактирования
    return BreathSessionDTO(
      description: existingSession!.description,
      shared: existingSession!.shared,
      exercises: existingSession!.exercises
          .map((set) => _exerciseSetToEditModel(set))
          .toList(),
    );
  }

  @override
  ConstructorMode getInitialConstructorMode() {
    if (existingSession != null) {
      return existingSession!.userId == userId ? ConstructorMode.edit : ConstructorMode.create;
    }
    return ConstructorMode.create;
  }

  @override
  Future<void> save(BreathSessionDTO dto) async {
    // Конвертируем упражнения из DTO в доменную модель
    final exercises = dto.exercises
        .map((e) => _editModelToExerciseSet(e))
        .toList();

    // Создаём или обновляем сессию
    final session = BreathSession(
      id: existingSession?.id ?? const Uuid().v4(),
      userId: userId,
      description: dto.description,
      shared: dto.shared,
      exercises: exercises,
    );

    // Сохраняем в репозиторий
    await provider.save(session);
  }

  @override
  Future<void> delete() async {
    // Если сессии нет (режим создания) — ничего не делаем
    if (existingSession == null) return;

    // Удаляем существующую сессию
    await provider.delete(existingSession!.id);
  }

  // ===== PRIVATE MAPPING =====

  ExerciseEditCellModel _exerciseSetToEditModel(ExerciseSet set) {
    int inhale = 0;
    int hold1 = 0;
    int exhale = 0;
    int hold2 = 0;

    for (int i = 0; i < set.steps.length; i++) {
      final step = set.steps[i];

      switch (step.type) {
        case StepType.inhale:
          inhale = step.duration;
          break;

        case StepType.exhale:
          exhale = step.duration;
          break;

        case StepType.hold:
          final hasExhaleBefore = set.steps
              .take(i)
              .any((s) => s.type == StepType.exhale);

          if (hasExhaleBefore) {
            hold2 = step.duration;
          } else {
            hold1 = step.duration;
          }
          break;
      }
    }

    return ExerciseEditCellModel(
      id: const Uuid().v4(),
      inhale: inhale,
      hold1: hold1,
      exhale: exhale,
      hold2: hold2,
      cycles: set.repeatCount,
      rest: set.restDuration,
    );
  }

  ExerciseSet _editModelToExerciseSet(ExerciseEditCellModel model) {
    final steps = <ExerciseStep>[];

    if (model.inhale > 0) {
      steps.add(
        ExerciseStep(type: StepType.inhale, duration: model.inhale),
      );
    }
    if (model.hold1 > 0) {
      steps.add(
        ExerciseStep(type: StepType.hold, duration: model.hold1),
      );
    }
    if (model.exhale > 0) {
      steps.add(
        ExerciseStep(type: StepType.exhale, duration: model.exhale),
      );
    }
    if (model.hold2 > 0) {
      steps.add(
        ExerciseStep(type: StepType.hold, duration: model.hold2),
      );
    }

    return ExerciseSet(
      steps: steps,
      restDuration: model.rest,
      repeatCount: model.cycles,
    );
  }
}
