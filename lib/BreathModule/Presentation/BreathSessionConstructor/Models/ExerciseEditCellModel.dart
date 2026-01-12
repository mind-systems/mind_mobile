import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Models/ExerciseStep.dart';

class ExerciseEditCellModel {
  final String id;
  int inhale;
  int hold1;
  int exhale;
  int hold2;
  int cycles;
  int rest;

  ExerciseEditCellModel({
    required this.id,
    this.inhale = 0,
    this.hold1 = 0,
    this.exhale = 0,
    this.hold2 = 0,
    this.cycles = 1,
    this.rest = 0,
  });

  // Создание нового упражнения с генерацией ID
  factory ExerciseEditCellModel.create() {
    return ExerciseEditCellModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
    );
  }

  // Расчёт длительности одного цикла
  int get cycleDuration => inhale + hold1 + exhale + hold2;

  // Расчёт общей длительности всех циклов (без учета отдыха между ними)
  int get totalCyclesDuration => cycleDuration * cycles;

  // Расчёт полной длительности упражнения включая отдых между циклами
  int get totalDuration {
    // Отдых идёт между циклами, поэтому (cycles - 1) * rest
    final restBetweenCycles = cycles > 1 ? (cycles - 1) * rest : 0;
    return totalCyclesDuration + restBetweenCycles;
  }

  // Определение формы на основе ненулевых фаз
  SetShape? get shape {
    final nonZeroSteps = _getNonZeroSteps();

    if (nonZeroSteps.length == 2) return SetShape.circle;
    if (nonZeroSteps.length == 3) {
      // Если последний шаг hold - треугольник вверх, иначе вниз
      return nonZeroSteps.last == StepType.hold
          ? SetShape.triangleUp
          : SetShape.triangleDown;
    }
    if (nonZeroSteps.length == 4) return SetShape.square;

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

  // Конвертация в ExerciseSet для рантайма
  ExerciseSet toExerciseSet() {
    final steps = <ExerciseStep>[];

    if (inhale > 0) {
      steps.add(ExerciseStep(type: StepType.inhale, duration: inhale));
    }
    if (hold1 > 0) {
      steps.add(ExerciseStep(type: StepType.hold, duration: hold1));
    }
    if (exhale > 0) {
      steps.add(ExerciseStep(type: StepType.exhale, duration: exhale));
    }
    if (hold2 > 0) {
      steps.add(ExerciseStep(type: StepType.hold, duration: hold2));
    }

    return ExerciseSet(
      steps: steps,
      restDuration: rest,
      repeatCount: cycles,
    );
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

  // Создание из ExerciseSet (для редактирования существующей сессии)
  factory ExerciseEditCellModel.fromExerciseSet(ExerciseSet set, {String? id}) {
    int inhale = 0;
    int hold1 = 0;
    int exhale = 0;
    int hold2 = 0;

    // Восстанавливаем значения из steps по порядку
    // Логика: inhale → hold1 → exhale → hold2
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
          // Определяем позицию hold по контексту
          // Если inhale ещё не было или уже был exhale → это граничные случаи
          // Нормальный порядок: inhale(0) → hold(1) → exhale(2) → hold(3)

          // Проверяем что было до этого hold
          bool hasInhaleBefore = false;
          bool hasExhaleBefore = false;

          for (int j = 0; j < i; j++) {
            if (set.steps[j].type == StepType.inhale) hasInhaleBefore = true;
            if (set.steps[j].type == StepType.exhale) hasExhaleBefore = true;
          }

          if (!hasInhaleBefore) {
            // Hold до вдоха - невозможный случай, но на всякий случай
            hold1 = step.duration;
          } else if (hasInhaleBefore && !hasExhaleBefore) {
            // Hold после вдоха, но до выдоха → hold1
            hold1 = step.duration;
          } else {
            // Hold после выдоха → hold2
            hold2 = step.duration;
          }
          break;
      }
    }

    return ExerciseEditCellModel(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      inhale: inhale,
      hold1: hold1,
      exhale: exhale,
      hold2: hold2,
      cycles: set.repeatCount,
      rest: set.restDuration,
    );
  }
}
