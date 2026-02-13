import 'package:mind/BreathModule/Models/StepType.dart';
import 'package:uuid/uuid.dart';

enum ExerciseIcon {
  circle,
  triangleUp,
  triangleDown,
  square,
  rest,
}

class ExerciseEditCellModel {
  final String id;
  final int inhale;
  final int hold1;
  final int exhale;
  final int hold2;
  final int cycles;
  final int rest;

  ExerciseEditCellModel({
    required this.id,
    required this.inhale,
    required this.hold1,
    required this.exhale,
    required this.hold2,
    required this.cycles,
    required this.rest,
  });

  // Создание нового упражнения с генерацией ID
  factory ExerciseEditCellModel.create() {
    return ExerciseEditCellModel(
      id: const Uuid().v4(),
      inhale: 0,
      hold1: 0,
      exhale: 0,
      hold2: 0,
      cycles: 1,
      rest: 0,
    );
  }

  // Расчёт длительности одного цикла
  int get cycleDuration => inhale + hold1 + exhale + hold2;

  // Расчёт общей длительности всех циклов (без учета отдыха между ними)
  int get totalCyclesDuration => cycleDuration * cycles;

  // Расчёт полной длительности упражнения включая отдых между циклами
  int get totalDuration {
      // Если это rest-only упражнение (все фазы = 0)
    if (cycleDuration == 0) {
      return rest;
    }

    // Отдых идёт между циклами, поэтому (cycles - 1) * rest
    final restBetweenCycles = cycles > 1 ? (cycles - 1) * rest : 0;
    return totalCyclesDuration + restBetweenCycles;
  }

  // Определение формы на основе ненулевых фаз
  ExerciseIcon? get icon {
    final nonZeroSteps = _getNonZeroSteps();

    if (nonZeroSteps.length == 2) return ExerciseIcon.circle;
    if (nonZeroSteps.length == 3) {
      // Если последний шаг hold - треугольник вверх, иначе вниз
      return nonZeroSteps.last == StepType.hold
          ? ExerciseIcon.triangleUp
          : ExerciseIcon.triangleDown;
    }
    if (nonZeroSteps.length == 4) return ExerciseIcon.square;

    if (isRestOnly) return ExerciseIcon.rest;

    return null;
  }

  // Проверка валидности упражнения
  bool get isValid {
    // Валидное если есть хотя бы одна ненулевая фаза дыхания
    // Или если это rest-only упражнение
    return cycleDuration > 0 || rest > 0;
  }

  // Проверка, является ли упражнение только отдыхом
  bool get isRestOnly => cycleDuration == 0 && rest > 0;

  // Получение списка ненулевых шагов для определения формы
  List<StepType> _getNonZeroSteps() {
    final steps = <StepType>[];

    if (inhale > 0) steps.add(StepType.inhale);
    if (hold1 > 0) steps.add(StepType.hold);
    if (exhale > 0) steps.add(StepType.exhale);
    if (hold2 > 0) steps.add(StepType.hold);

    return steps;
  }

  // Копирование с изменением параметров
  ExerciseEditCellModel copyWith({
    String? id,
    int? inhale,
    int? hold1,
    int? exhale,
    int? hold2,
    int? cycles,
    int? rest,
  }) {
    return ExerciseEditCellModel(
      id: id ?? this.id,
      inhale: inhale ?? this.inhale,
      hold1: hold1 ?? this.hold1,
      exhale: exhale ?? this.exhale,
      hold2: hold2 ?? this.hold2,
      cycles: cycles ?? this.cycles,
      rest: rest ?? this.rest,
    );
  }
}
