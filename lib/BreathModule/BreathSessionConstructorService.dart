import 'package:mind/BreathModule/Core/BreathSessionProvider.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/IBreathSessionConstructorService.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/BreathSessionConstructorState.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/BreathSessionDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/Models/ExerciseEditCellModel.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
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
      tickSource: existingSession!.tickSource,
      exercises: existingSession!.exercises
          .map((set) => ExerciseEditCellModel.fromExerciseSet(set))
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
        .map((e) => e.toExerciseSet())
        .toList();

    // Создаём или обновляем сессию
    final session = BreathSession(
      id: existingSession?.id ?? const Uuid().v4(),
      userId: userId,
      description: dto.description,
      shared: dto.shared,
      tickSource: dto.tickSource,
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
}
