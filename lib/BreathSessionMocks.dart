import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/ExerciseStep.dart';
import 'package:mind/BreathModule/Presentation/CommonModels/TickSource.dart';

import 'BreathModule/Models/StepType.dart';

/// Моки дыхательных сессий для тестирования
class BreathSessionMocks {
  // ==================== Отдельные упражнения ====================

  /// Простое дыхание: вдох-выдох (4-4)
  static final simpleBreathing = ExerciseSet(
    steps: [
      ExerciseStep(type: StepType.inhale, duration: 2),
      ExerciseStep(type: StepType.exhale, duration: 1),
    ],
    restDuration: 5,
    repeatCount: 10,
  );

  /// Треугольное дыхание: вдох-задержка-выдох (2-2-2)
  static final triangleDownBreathing = ExerciseSet(
    steps: [
      ExerciseStep(type: StepType.inhale, duration: 1),
      ExerciseStep(type: StepType.hold, duration: 1),
      ExerciseStep(type: StepType.exhale, duration: 1),
    ],
    restDuration: 3,
    repeatCount: 1,
  );

  /// Быстрое треугольное дыхание: (1-1-1)
  static final quickTriangleBreathing = ExerciseSet(
    steps: [
      ExerciseStep(type: StepType.inhale, duration: 1),
      ExerciseStep(type: StepType.hold, duration: 1),
      ExerciseStep(type: StepType.exhale, duration: 1),
    ],
    restDuration: 2,
    repeatCount: 1,
  );

  /// Квадратное дыхание: вдох-задержка-выдох-задержка (1-1-1-1)
  static final boxBreathing = ExerciseSet(
    steps: [
      ExerciseStep(type: StepType.inhale, duration: 1),
      ExerciseStep(type: StepType.hold, duration: 1),
      ExerciseStep(type: StepType.exhale, duration: 1),
      ExerciseStep(type: StepType.hold, duration: 1),
    ],
    restDuration: 0,
    repeatCount: 3,
  );

  static final boxBreathingWithRest = ExerciseSet(
    steps: [
      ExerciseStep(type: StepType.inhale, duration: 1),
      ExerciseStep(type: StepType.hold, duration: 1),
      ExerciseStep(type: StepType.exhale, duration: 1),
      ExerciseStep(type: StepType.hold, duration: 1),
    ],
    restDuration: 0,
    repeatCount: 3,
  );

  /// Дыхание с задержкой после выдоха: вдох-выдох-задержка (2-2-2)
  static final triangleUpBreathing = ExerciseSet(
    steps: [
      ExerciseStep(type: StepType.inhale, duration: 1),
      ExerciseStep(type: StepType.exhale, duration: 1),
      ExerciseStep(type: StepType.hold, duration: 1),
    ],
    restDuration: 3,
    repeatCount: 1,
  );

  /// Простое дыхание без задержек: вдох-выдох (2-2)
  static final circleBreathing = ExerciseSet(
    steps: [
      ExerciseStep(type: StepType.inhale, duration: 1),
      ExerciseStep(type: StepType.exhale, duration: 1),
    ],
    restDuration: 3,
    repeatCount: 1,
  );

  // ==================== Перерывы ====================

  /// Короткий отдых (3 секунды)
  static final shortRest = ExerciseSet(
    steps: [],
    restDuration: 3,
    repeatCount: 0,
  );

  /// Средний отдых (5 секунд)
  static final mediumRest = ExerciseSet(
    steps: [],
    restDuration: 5,
    repeatCount: 0,
  );

  /// Длинный отдых (10 секунд)
  static final longRest = ExerciseSet(
    steps: [],
    restDuration: 10,
    repeatCount: 0,
  );

  // ==================== Готовые сессии ====================

  /// Полная тестовая сессия (все типы упражнений)
  static BreathSession get fullTestSession => BreathSession(
    id: '1',
    userId: '1',
    description: 'Full test session',
    shared: false,
    exercises: [
      shortRest,
      triangleDownBreathing,
      shortRest,
      boxBreathing,
      shortRest,
      triangleUpBreathing,
      mediumRest,
      circleBreathing,
      shortRest,
      triangleDownBreathing,
      mediumRest,
      triangleUpBreathing,
      mediumRest,
    ],
    tickSource: TickSource.heartbeat,
  );

  /// Быстрая тестовая сессия (для быстрого тестирования)
  static BreathSession get quickTestSession => BreathSession(
    id: '2',
    userId: '1',
    description: 'Quick test session',
    shared: false,
    exercises: [
      shortRest,
      quickTriangleBreathing,
      shortRest,
    ],
    tickSource: TickSource.heartbeat,
  );

  /// Только треугольное дыхание
  static BreathSession get triangleOnlySession => BreathSession(
    id: '3',
    userId: '1',
    description: 'Triangle only session',
    shared: false,
    exercises: [
      shortRest,
      triangleDownBreathing,
      triangleUpBreathing,
      shortRest,
    ],
    tickSource: TickSource.heartbeat,
  );

  /// Только квадратное дыхание
  static BreathSession get boxOnlySession => BreathSession(
    id: '4',
    userId: '1',
    description: 'Box only session',
    shared: false,
    exercises: [
      shortRest,
      boxBreathing,
      shortRest,
      boxBreathingWithRest,
      shortRest,
    ],
    tickSource: TickSource.heartbeat,
  );

  /// Микс разных форм
  static BreathSession get mixedShapesSession => BreathSession(
    id: '5',
    userId: '1',
    description: 'Mixed shapes session',
    shared: false,
    exercises: [
      shortRest,
      circleBreathing, // круг
      shortRest,
      triangleDownBreathing, // треугольник
      shortRest,
      boxBreathing, // квадрат
      mediumRest,
    ],
    tickSource: TickSource.heartbeat,
  );

  /// Длинная сессия для стресс-теста
  static BreathSession get longSession => BreathSession(
    id: '6',
    userId: '1',
    description: 'Long session',
    shared: false,
    exercises: [
      shortRest,
      simpleBreathing,
      mediumRest,
      triangleDownBreathing,
      mediumRest,
      boxBreathing,
      mediumRest,
      triangleUpBreathing,
      longRest,
    ],
    tickSource: TickSource.heartbeat,
  );
}
