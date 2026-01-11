import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/ITickService.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Models/ExerciseStep.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/TimelineStep.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';

enum ResetReason {
  newCycle,
  rest,
  exerciseChange,
}

final breathViewModelProvider =
    StateNotifierProvider<BreathViewModel, BreathSessionState>((ref) {
  throw UnimplementedError(
    'BreathViewModel должен быть передан через override в BreathModule',
  );
});

class BreathViewModel extends StateNotifier<BreathSessionState> {
  final ITickService tickService;
  final BreathSession session;

  StreamSubscription<TickData>? _subscription;

  // Контроллер для события сброса цикла
  final _resetController = StreamController<ResetReason>.broadcast();
  Stream<ResetReason> get resetStream => _resetController.stream;

  // Текущее состояние сессии (внутренние счетчики)
  int _exerciseIndex = 0; // индекс упражнения в сете
  int _repeatCounter = 0; // счетчик повторений сета
  int _cycleTick = 0;     // текущий тик цикла

  ExerciseSet get currentExercise => session.exercises[_exerciseIndex];

  BreathViewModel({required this.tickService, required this.session})
      : super(BreathSessionState.initial());

  // ===== Lifecycle =====

  void initState() {
    _generateTimelineSteps();

    // Проверяем первое упражнение
    final firstExercise = session.exercises[0];

    // Если первое упражнение - это подготовка (пустые steps, только rest)
    if (firstExercise.steps.isEmpty && firstExercise.restDuration > 0) {
      _setupInitialRest();
    } else {
      _setupInitialBreath();
    }

    _subscription = tickService.tickStream.listen(_onTick);
  }

  void _generateTimelineSteps() {
    final List<TimelineStep> steps = [];

    for (var exerciseIndex = 0; exerciseIndex < session.exercises.length; exerciseIndex++) {
      final exercise = session.exercises[exerciseIndex];

      // separator между сетами (кроме первого)
      if (exerciseIndex > 0) {
        steps.add(const TimelineStep(type: TimelineStepType.separator));
      }

      // === СЕТ ТОЛЬКО С ОТДЫХОМ ===
      if (exercise.steps.isEmpty && exercise.restDuration > 0) {
        // для standalone rest repeatCounter и cycleTick всегда 0
        steps.add(
          TimelineStep(
            type: TimelineStepType.rest,
            duration: exercise.restDuration,
            id: TimelineStep.generateId(
              exerciseIndex: exerciseIndex,
              repeatCounter: 0,
              stepIndex: 0,
            ),
          ),
        );
        continue;
      }

      // === ДЫХАТЕЛЬНЫЙ СЕТ ===
      for (var repeatCounter = 0; repeatCounter < exercise.repeatCount; repeatCounter++) {
        // дыхательные шаги цикла
        for (var stepIndex = 0; stepIndex < exercise.steps.length; stepIndex++) {
          final step = exercise.steps[stepIndex];
          steps.add(
            TimelineStep(
              type: TimelineStep.mapStepTypeToTimelineType(step.type),
              duration: step.duration,
              id: TimelineStep.generateId(
                exerciseIndex: exerciseIndex,
                repeatCounter: repeatCounter,
                stepIndex: stepIndex,
              ),
            ),
          );
        }

        // отдых между повторами
        final isLastRepeat = repeatCounter == exercise.repeatCount - 1;
        if (!isLastRepeat && exercise.restDuration > 0) {
          steps.add(
            TimelineStep(
              type: TimelineStepType.rest,
              duration: exercise.restDuration,
              id: TimelineStep.generateId(
                exerciseIndex: exerciseIndex,
                repeatCounter: repeatCounter + 1,
                stepIndex: 0,
              ),
            ),
          );
        }
      }
    }

    state = state.copyWith(timelineSteps: steps);
  }

  void _setupInitialRest() {
    state = state.copyWith(
      status: BreathSessionStatus.pause,
      phase: BreathPhase.rest,
      exerciseIndex: _exerciseIndex,
      remainingTicks: currentExercise.restDuration,
      activeStepId: TimelineStep.generateId(
        exerciseIndex: _exerciseIndex,
        repeatCounter: 0,
        stepIndex: 0,
      ),
      currentIntervalMs: -1,
    );
  }

  void _setupInitialBreath() {
    final initialStepData = _getCurrentStepData(0);

    state = state.copyWith(
      status: BreathSessionStatus.pause,
      phase: initialStepData.phase,
      exerciseIndex: _exerciseIndex,
      remainingTicks: initialStepData.remainingTicks,
      activeStepId: TimelineStep.generateId(
        exerciseIndex: _exerciseIndex,
        repeatCounter: 0,
        stepIndex: 0,
      ),
      currentIntervalMs: -1,
    );
  }

  void pause() {
    if (state.status != BreathSessionStatus.complete) {
      state = state.copyWith(status: BreathSessionStatus.pause);
    }
  }

  void resume() {
    if (state.status == BreathSessionStatus.pause) {
      final wasResting = state.phase == BreathPhase.rest;
      state = state.copyWith(
        status: wasResting
            ? BreathSessionStatus.rest
            : BreathSessionStatus.breath,
      );
    }
  }

  void complete() {
    state = state.copyWith(status: BreathSessionStatus.complete);
    _subscription?.cancel();
    _resetController.close();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _resetController.close();
    super.dispose();
  }

  // ===== Tick processing =====

  void _onTick(TickData tickData) {
    state = state.copyWith(currentIntervalMs: tickData.intervalMs);

    // Проверяем активность
    if (state.status == BreathSessionStatus.pause ||
        state.status == BreathSessionStatus.complete) {
      return;
    }

    switch (state.status) {
      case BreathSessionStatus.breath:
        _onBreathTick(tickData.intervalMs);
        break;
      case BreathSessionStatus.rest:
        _onRestTick(tickData.intervalMs);
        break;
      default:
        break;
    }
  }

  void _onBreathTick(int intervalMs) {
    _cycleTick++;

    final cycleDuration = currentExercise.cycleDuration;

    // 1. Проверяем завершение цикла
    if (_cycleTick >= cycleDuration) {
      _cycleTick = 0;
      _repeatCounter++;

      // Проверяем завершение всех повторений упражнения
      if (_repeatCounter >= currentExercise.repeatCount) {
        _repeatCounter = 0;
        _advanceExercise(intervalMs);
        return;
      }

      // Отдых после каждого подхода (если он задан внутри сета)
      if (currentExercise.restDuration > 0) {
        _startRest(intervalMs);
        return;
      }

      // Если отдыха нет, начинаем новый цикл
      _startNewCycle(intervalMs);
      return;
    }

    // 2. Если цикл не закончен, определяем текущий шаг
    final stepData = _getCurrentStepData(_cycleTick);

    // Генерим ID после всех изменений счётчиков
    final activeStepId = TimelineStep.generateId(
      exerciseIndex: _exerciseIndex,
      repeatCounter: _repeatCounter,
      stepIndex: stepData.stepIndex,
    );

    state = state.copyWith(
      status: BreathSessionStatus.breath,
      phase: stepData.phase,
      exerciseIndex: _exerciseIndex,
      remainingTicks: stepData.remainingTicks,
      activeStepId: activeStepId,
      currentIntervalMs: intervalMs,
    );
  }

  void _onRestTick(int intervalMs) {
    _cycleTick++;

    final restDuration = currentExercise.restDuration;
    final remainingTicks = restDuration - _cycleTick;

    if (_cycleTick >= restDuration) {
      _cycleTick = 0;

      // Определяем тип отдыха по структуре текущего упражнения
      if (currentExercise.steps.isEmpty) {
        // Это был самостоятельный отдых (отдельное упражнение) → идём дальше
        _advanceExercise(intervalMs);
        return;
      }

      // Это был отдых между циклами упражнения → начинаем новый цикл
      _startNewCycle(intervalMs);
      return;
    }

    // Генерим ID после всех изменений счётчиков
    final activeStepId = TimelineStep.generateId(
      exerciseIndex: _exerciseIndex,
      repeatCounter: _repeatCounter,
      stepIndex: 0,
    );

    state = state.copyWith(
      status: BreathSessionStatus.rest,
      phase: BreathPhase.rest,
      exerciseIndex: _exerciseIndex,
      remainingTicks: remainingTicks,
      activeStepId: activeStepId,
      currentIntervalMs: intervalMs,
    );
  }

  // ===== Step calculation =====

  ({BreathPhase phase, int remainingTicks, int stepIndex}) _getCurrentStepData(int tick) {
    int accumulated = 0;

    for (int i = 0; i < currentExercise.steps.length; i++) {
      final step = currentExercise.steps[i];
      if (tick < accumulated + step.duration) {
        final remainingInCycle = currentExercise.cycleDuration - tick;
        return (phase: _mapStepTypeToPhase(step.type), remainingTicks: remainingInCycle, stepIndex: i);
      }
      accumulated += step.duration;
    }

    // Если tick == cycleDuration (или больше)
    final lastStep = currentExercise.steps.last;
    return (phase: _mapStepTypeToPhase(lastStep.type), remainingTicks: 0, stepIndex: currentExercise.steps.length - 1);
  }

  BreathPhase _mapStepTypeToPhase(StepType stepType) {
    switch (stepType) {
      case StepType.inhale: return BreathPhase.inhale;
      case StepType.hold:   return BreathPhase.hold;
      case StepType.exhale: return BreathPhase.exhale;
    }
  }

  // ===== Transitions =====

  void _startRest(int intervalMs) {
    _cycleTick = 0;

    // Уведомляем о смене контекста (визуально это может быть другая фигура или режим)
    _resetController.add(ResetReason.rest);

    state = state.copyWith(
      status: BreathSessionStatus.rest,
      phase: BreathPhase.rest,
      exerciseIndex: _exerciseIndex,
      remainingTicks: currentExercise.restDuration,
      activeStepId: TimelineStep.generateId(
        exerciseIndex: _exerciseIndex,
        repeatCounter: _repeatCounter,
        stepIndex: 0,
      ),
      currentIntervalMs: intervalMs,
    );
  }

  void _startNewCycle(int intervalMs) {
    // Сигнал для визуального слоя: "Мы начали сначала" (нужен сброс rawPosition)
    _resetController.add(ResetReason.newCycle);

    final stepData = _getCurrentStepData(0);

    state = state.copyWith(
      status: BreathSessionStatus.breath,
      phase: stepData.phase,
      exerciseIndex: _exerciseIndex,
      remainingTicks: stepData.remainingTicks,
      activeStepId: TimelineStep.generateId(
        exerciseIndex: _exerciseIndex,
        repeatCounter: _repeatCounter,
        stepIndex: stepData.stepIndex,
      ),
      currentIntervalMs: intervalMs,
    );
  }

  void _advanceExercise(int intervalMs) {
    _exerciseIndex++;

    if (_exerciseIndex >= session.exercises.length) {
      complete();
      return;
    }

    // Сбрасываем цикл
    _cycleTick = 0;
    _repeatCounter = 0;

    // Уведомляем о глобальной смене упражнения
    // todo здесь не нужен этот резет. он вызовется на стартРэст или стартНьюСайкл. Возможно нужен на комплит..
    _resetController.add(ResetReason.exerciseChange);

    final nextExercise = session.exercises[_exerciseIndex];

    // Если следующее упражнение - только отдых
    if (nextExercise.steps.isEmpty && nextExercise.restDuration > 0) {
      _startRest(intervalMs);
    } else {
      _startNewCycle(intervalMs);
    }
  }

  // ===== Current phase info =====

  /// Возвращает информацию о текущей фазе: её тип и оставшееся количество тиков именно в этой фазе.
  ({BreathPhase phase, int remainingInPhase}) getCurrentPhaseInfo() {
    if (state.status == BreathSessionStatus.complete) {
      return (phase: BreathPhase.rest, remainingInPhase: 0);
    }

    // Режим отдыха — отдельная логика
    if (state.status == BreathSessionStatus.rest || state.phase == BreathPhase.rest) {
      final remainingInRest = currentExercise.restDuration - _cycleTick;
      return (phase: BreathPhase.rest, remainingInPhase: remainingInRest.clamp(0, remainingInRest));
    }

    // Если steps пустые — это не ошибка, просто сейчас нет активной дыхательной фазы
    if (currentExercise.steps.isEmpty) {
      return (phase: BreathPhase.rest, remainingInPhase: 0);
    }

    // Режим дыхания — ищем текущий шаг
    int accumulated = 0;
    int currentTickInCycle = _cycleTick;

    for (final step in currentExercise.steps) {
      if (currentTickInCycle < accumulated + step.duration) {
        final remainingInThisStep = (accumulated + step.duration) - currentTickInCycle;
        return (
          phase: _mapStepTypeToPhase(step.type),
          remainingInPhase: remainingInThisStep,
        );
      }
      accumulated += step.duration;
    }

    // Если по какой-то причине вышли за пределы (крайний тик цикла)
    final lastStep = currentExercise.steps.last;
    return (
      phase: _mapStepTypeToPhase(lastStep.type),
      remainingInPhase: 0,
    );
  }

  // ===== Next exercise (Forecast) =====

  ExerciseSet? getNextExerciseWithShape() {
    // текущий сет
    final current = currentExercise;

    // если текущий сет сам имеет форму — она и есть актуальная
    if (current.steps.isNotEmpty) {
      return current;
    }

    // иначе ищем следующий дыхательный сет
    for (int i = _exerciseIndex + 1; i < session.exercises.length; i++) {
      final candidate = session.exercises[i];
      if (candidate.steps.isNotEmpty) {
        return candidate;
      }
    }

    return null;
  }

  // ===== Next phase info (Forecast) =====

  /// Возвращает информацию о следующей фазе для отображения в UI.
  ({BreathPhase phase, int duration})? getNextPhaseInfo() {
    if (state.status == BreathSessionStatus.complete) {
      return null;
    }

    // Логика для режима дыхания
    if (state.status == BreathSessionStatus.breath) {
      int accumulated = 0;
      int currentStepIndex = -1;

      for (int i = 0; i < currentExercise.steps.length; i++) {
        if (_cycleTick < accumulated + currentExercise.steps[i].duration) {
          currentStepIndex = i;
          break;
        }
        accumulated += currentExercise.steps[i].duration;
      }

      // 1. Следующий шаг внутри текущего цикла
      if (currentStepIndex >= 0 && currentStepIndex < currentExercise.steps.length - 1) {
        final nextStep = currentExercise.steps[currentStepIndex + 1];
        return (phase: _mapStepTypeToPhase(nextStep.type), duration: nextStep.duration);
      }

      // 2. Новый цикл или отдых между циклами
      if (_repeatCounter + 1 < currentExercise.repeatCount) {
        if (currentExercise.restDuration > 0) {
          return (phase: BreathPhase.rest, duration: currentExercise.restDuration);
        } else {
          final firstStep = currentExercise.steps.first;
          return (phase: _mapStepTypeToPhase(firstStep.type), duration: firstStep.duration);
        }
      }

      // 3. Следующее упражнение
      if (_exerciseIndex + 1 < session.exercises.length) {
        final nextExercise = session.exercises[_exerciseIndex + 1];
        if (nextExercise.steps.isEmpty && nextExercise.restDuration > 0) {
          return (phase: BreathPhase.rest, duration: nextExercise.restDuration);
        } else if (nextExercise.steps.isNotEmpty) {
          final firstStep = nextExercise.steps.first;
          return (phase: _mapStepTypeToPhase(firstStep.type), duration: firstStep.duration);
        }
      }
      return null;
    }

    // Логика для режима отдыха или паузы
    if (state.status == BreathSessionStatus.rest || state.status == BreathSessionStatus.pause) {
      // Отдых между повторами
      if (_repeatCounter < currentExercise.repeatCount) {
        final firstStep = currentExercise.steps.first;
        return (phase: _mapStepTypeToPhase(firstStep.type), duration: firstStep.duration);
      }
      // Отдых перед следующим упражнением
      if (_exerciseIndex + 1 < session.exercises.length) {
        final nextExercise = session.exercises[_exerciseIndex + 1];
        if (nextExercise.steps.isNotEmpty) {
          final firstStep = nextExercise.steps.first;
          return (phase: _mapStepTypeToPhase(firstStep.type), duration: firstStep.duration);
        }
      }
    }

    return null;
  }
}
