import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/ITickService.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Models/ExerciseStep.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/Views/BreathWidget.dart';

final breathViewModelProvider =
    StateNotifierProvider<BreathViewModel, BreathSessionState>((ref) {
  throw UnimplementedError(
    'BreathViewModel должен быть передан через override в BreathModule',
  );
});

class BreathViewModel extends StateNotifier<BreathSessionState> {
  final ITickService tickService;
  final BreathSession session; // сессия состоит из наборов упражнений (дыхание-разогрев, отдых, основной сет)
  late final BreathShapeController shapeController;

  StreamSubscription<TickData>? _subscription;

  // Текущее состояние сессии
  int _exerciseIndex = 0; // индекс упражнения в сете
  int _repeatCounter = 0; // счетчик повторений сета
  int _cycleTick = 0; // текущий тик цикла

  ExerciseSet get currentExercise => session.exercises[_exerciseIndex];

  BreathViewModel({required this.tickService, required this.session})
      : super(BreathSessionState.initial()) {
    shapeController = BreathShapeController();
  }

  // ===== Lifecycle =====

  void initState() {
    // Проверяем первое упражнение
    final firstExercise = session.exercises[0];

    // Если первое упражнение - это подготовка (пустые steps, только rest)
    if (firstExercise.steps.isEmpty && firstExercise.restDuration > 0) {
      // Начинаем с отдыха
      _setupInitialRest();
    } else {
      // Начинаем с дыхания
      _setupInitialBreath();
    }

    _subscription = tickService.tickStream.listen(_onTick);
  }

  void _setupInitialRest() {
    state = BreathSessionState(
      status: BreathSessionStatus.pause,
      phase: BreathPhase.rest,
      exerciseIndex: _exerciseIndex,
      remainingTicks: currentExercise.restDuration,
      shapeProgress: 0.0,
    );
  }

  void _setupInitialBreath() {
    final initialStepData = _getCurrentStepData(0);
    final initialProgress = _mapTickToProgress(0);

    shapeController.setProgressImmediately(initialProgress);

    state = BreathSessionState(
      status: BreathSessionStatus.pause,
      phase: initialStepData.phase,
      exerciseIndex: _exerciseIndex,
      remainingTicks: initialStepData.remainingTicks,
      shapeProgress: initialProgress,
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
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // ===== Tick processing =====

  void _onTick(TickData tickData) {
    switch (state.status) {
      case BreathSessionStatus.pause:
        break;
      case BreathSessionStatus.breath:
        _onBreathTick(tickData.intervalMs);
        break;
      case BreathSessionStatus.rest:
        _onRestTick(tickData.intervalMs);
        break;
      case BreathSessionStatus.complete:
        break;
    }
  }

  void _onBreathTick(int intervalMs) {
    _cycleTick++;

    final cycleDuration = currentExercise.cycleDuration;

    // Проверяем завершение цикла
    if (_cycleTick >= cycleDuration) {
      _cycleTick = 0;
      _repeatCounter++;

      // Проверяем завершение всех повторений
      if (_repeatCounter >= currentExercise.repeatCount) {
        _repeatCounter = 0;
        _advanceExercise();
        return;
      }

      // Отдых после каждого подхода (если он задан)
      if (currentExercise.restDuration > 0) {
        _startRest();
        return;
      }

      // Если отдыха нет, начинаем новый цикл с tick = 0
      _startNewCycle();
      return;
    }

    // Определяем текущий шаг и оставшиеся тики
    final stepData = _getCurrentStepData(_cycleTick);
    final targetProgress = _mapTickToProgress(_cycleTick);

    shapeController.animateToProgress(
      targetProgress,
      Duration(milliseconds: intervalMs),
    );

    state = BreathSessionState(
      status: BreathSessionStatus.breath,
      phase: stepData.phase,
      exerciseIndex: _exerciseIndex,
      remainingTicks: stepData.remainingTicks,
      shapeProgress: targetProgress,
    );
  }

  void _onRestTick(int intervalMs) {
    _cycleTick++;

    final restDuration = currentExercise.restDuration;
    final remainingTicks = restDuration - _cycleTick;

    if (_cycleTick >= restDuration) {
      _cycleTick = 0;

      // После отдыха возвращаемся к дыханию или переходим к следующему упражнению
      if (_repeatCounter >= currentExercise.repeatCount) {
        _repeatCounter = 0;
        _advanceExercise();
      } else {
        _startNewCycle();
      }
      return;
    }

    final targetProgress = _mapRestTickToProgress(_cycleTick);

    shapeController.animateToProgress(
      targetProgress,
      Duration(milliseconds: intervalMs),
    );

    state = BreathSessionState(
      status: BreathSessionStatus.rest,
      phase: BreathPhase.rest,
      exerciseIndex: _exerciseIndex,
      remainingTicks: remainingTicks,
      shapeProgress: targetProgress,
    );
  }

  // ===== Step calculation =====

  ({BreathPhase phase, int remainingTicks}) _getCurrentStepData(int tick) {
    int accumulated = 0;

    for (final step in currentExercise.steps) {
      if (tick < accumulated + step.duration) { // если текущий тик меньше суммы текущего шага и предыдущих шагов. Если tick = 0,  accumulated = 0 + 3c, мы понимаем, что мы в первом шаге.
        final remaining = accumulated + step.duration - tick; // посчитали, сколько тиков осталось до конца текущего шага. а зачем? когда в интерфейсе отображается сумма всех шагов..
        return (phase: _mapStepTypeToPhase(step.type), remainingTicks: remaining);
      }
      accumulated += step.duration;
    }

    final lastStep = currentExercise.steps.last; // сюда попадает, когда тик == step1.duration + step2.duration + step3.duration. Т.е. мы в последнем шаге.
    return (phase: _mapStepTypeToPhase(lastStep.type), remainingTicks: 0); // todo как буд то тут может быть проблема. Вернул 0 и дальше что? Вообще я не видел в интерфейсе что б 0 показывался.
  }

  BreathPhase _mapStepTypeToPhase(StepType stepType) {
    switch (stepType) {
      case StepType.inhale:
        return BreathPhase.inhale;
      case StepType.hold:
        return BreathPhase.hold;
      case StepType.exhale:
        return BreathPhase.exhale;
    }
  }

  // ===== Progress mapping =====

  double _mapRestTickToProgress(int tick) {
    final total = currentExercise.restDuration;
    if (total == 0) return 0.0;

    return tick / total;
  }

  double _mapTickToProgress(int tick) {
    final total = currentExercise.cycleDuration;
    if (total == 0) return 0.0;

    if (currentExercise.shape == SetShape.circle) {
      return tick / total;
    }

    final segmentSize = 1.0 / currentExercise.steps.length;
    double cursor = 0.0;
    int remainingTick = tick;

    for (final step in currentExercise.steps) {
      if (remainingTick < step.duration) {
        return cursor + (remainingTick / step.duration) * segmentSize;
      }
      remainingTick -= step.duration;
      cursor += segmentSize;
    }

    return 1.0;
  }

  // ===== Exercise switching =====

  void _startRest() {
    _cycleTick = 0;
    state = state.copyWith(
      status: BreathSessionStatus.rest,
      phase: BreathPhase.rest,
      remainingTicks: currentExercise.restDuration,
    );
  }

  void _startNewCycle() {
    final stepData = _getCurrentStepData(0);
    final targetProgress = _mapTickToProgress(0);

    shapeController.setProgressImmediately(targetProgress);

    state = BreathSessionState(
      status: BreathSessionStatus.breath,
      phase: stepData.phase,
      exerciseIndex: _exerciseIndex,
      remainingTicks: stepData.remainingTicks,
      shapeProgress: targetProgress,
    );
  }

  void _advanceExercise() {
    _exerciseIndex++;

    if (_exerciseIndex >= session.exercises.length) {
      complete();
      return;
    }

    _resetCycle();

    final nextExercise = session.exercises[_exerciseIndex];

    // Если следующее упражнение - подготовка (только rest)
    if (nextExercise.steps.isEmpty && nextExercise.restDuration > 0) {
      _startRest();
    } else {
      _startNewCycle();
    }
  }

  void _resetCycle() {
    _cycleTick = 0;
    _repeatCounter = 0;
    shapeController.setProgressImmediately(0.0);
  }

  // ===== Next phase info =====

  /// Возвращает информацию о следующей фазе для отображения в UI
  ({BreathPhase phase, int duration})? getNextPhaseInfo() {
    if (state.status == BreathSessionStatus.complete) {
      return null;
    }

    // Если мы в процессе дыхания
    if (state.status == BreathSessionStatus.breath) {
      // Найдем текущий шаг
      int accumulated = 0;
      int currentStepIndex = -1;

      for (int i = 0; i < currentExercise.steps.length; i++) {
        if (_cycleTick < accumulated + currentExercise.steps[i].duration) {
          currentStepIndex = i;
          break;
        }
        accumulated += currentExercise.steps[i].duration;
      }

      // Есть ли следующий шаг в текущем цикле?
      if (currentStepIndex >= 0 && currentStepIndex < currentExercise.steps.length - 1) {
        final nextStep = currentExercise.steps[currentStepIndex + 1];
        return (
          phase: _mapStepTypeToPhase(nextStep.type),
          duration: nextStep.duration
        );
      }

      // Цикл заканчивается - что дальше?
      // Проверяем, будет ли еще повтор
      if (_repeatCounter + 1 < currentExercise.repeatCount) {
        // Будет еще повтор
        if (currentExercise.restDuration > 0) {
          // Сначала отдых
          return (phase: BreathPhase.rest, duration: currentExercise.restDuration);
        } else {
          // Сразу первый шаг нового цикла
          final firstStep = currentExercise.steps.first;
          return (
            phase: _mapStepTypeToPhase(firstStep.type),
            duration: firstStep.duration
          );
        }
      }

      // Текущее упражнение заканчивается - смотрим следующее
      if (_exerciseIndex + 1 < session.exercises.length) {
        final nextExercise = session.exercises[_exerciseIndex + 1];

        if (nextExercise.steps.isEmpty && nextExercise.restDuration > 0) {
          return (phase: BreathPhase.rest, duration: nextExercise.restDuration);
        } else if (nextExercise.steps.isNotEmpty) {
          final firstStep = nextExercise.steps.first;
          return (
            phase: _mapStepTypeToPhase(firstStep.type),
            duration: firstStep.duration
          );
        }
      }

      return null;
    }

    // Если мы в отдыхе
    if (state.status == BreathSessionStatus.rest) {
      // Отдых между повторами одного упражнения
      if (_repeatCounter < currentExercise.repeatCount) {
        final firstStep = currentExercise.steps.first;
        return (
          phase: _mapStepTypeToPhase(firstStep.type),
          duration: firstStep.duration
        );
      }

      // Отдых перед следующим упражнением
      if (_exerciseIndex + 1 < session.exercises.length) {
        final nextExercise = session.exercises[_exerciseIndex + 1];

        if (nextExercise.steps.isNotEmpty) {
          final firstStep = nextExercise.steps.first;
          return (
            phase: _mapStepTypeToPhase(firstStep.type),
            duration: firstStep.duration
          );
        }
      }

      return null;
    }

    return null;
  }
}
