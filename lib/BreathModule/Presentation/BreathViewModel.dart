import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/ITickService.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Models/ExerciseStep.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionState.dart';

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
  final _resetController = StreamController<void>.broadcast();
  Stream<void> get resetStream => _resetController.stream;

  // Текущее состояние сессии (внутренние счетчики)
  int _exerciseIndex = 0; // индекс упражнения в сете
  int _repeatCounter = 0; // счетчик повторений сета
  int _cycleTick = 0;     // текущий тик цикла

  ExerciseSet get currentExercise => session.exercises[_exerciseIndex];

  BreathViewModel({required this.tickService, required this.session})
      : super(BreathSessionState.initial());

  // ===== Lifecycle =====

  void initState() {
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

  void _setupInitialRest() {
    state = BreathSessionState(
      status: BreathSessionStatus.pause, // Начинаем на паузе
      phase: BreathPhase.rest,
      exerciseIndex: _exerciseIndex,
      remainingTicks: currentExercise.restDuration,
      // Дефолтное значение интервала до первого тика
      currentIntervalMs: 1000,
    );
  }

  void _setupInitialBreath() {
    final initialStepData = _getCurrentStepData(0);

    state = BreathSessionState(
      status: BreathSessionStatus.pause, // Начинаем на паузе
      phase: initialStepData.phase,
      exerciseIndex: _exerciseIndex,
      remainingTicks: initialStepData.remainingTicks,
      currentIntervalMs: 1000,
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

    // Если фаза сменилась по сравнению с предыдущим состоянием
    if (state.phase != stepData.phase) {
      _resetController.add(null);
    }

    state = BreathSessionState(
      status: BreathSessionStatus.breath,
      phase: stepData.phase,
      exerciseIndex: _exerciseIndex,
      remainingTicks: stepData.remainingTicks,
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

    state = BreathSessionState(
      status: BreathSessionStatus.rest,
      phase: BreathPhase.rest,
      exerciseIndex: _exerciseIndex,
      remainingTicks: remainingTicks,
      currentIntervalMs: intervalMs,
    );
  }

  // ===== Step calculation =====

  ({BreathPhase phase, int remainingTicks}) _getCurrentStepData(int tick) {
    int accumulated = 0;

    for (final step in currentExercise.steps) {
      if (tick < accumulated + step.duration) {
        final remaining = accumulated + step.duration - tick;
        return (phase: _mapStepTypeToPhase(step.type), remainingTicks: remaining);
      }
      accumulated += step.duration;
    }

    // Если мы попали сюда, значит tick == cycleDuration (или больше, что ошибка).
    // Возвращаем параметры последнего шага с 0 остатком.
    final lastStep = currentExercise.steps.last;
    return (phase: _mapStepTypeToPhase(lastStep.type), remainingTicks: 0);
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
    _resetController.add(null);

    state = state.copyWith(
      status: BreathSessionStatus.rest,
      phase: BreathPhase.rest,
      remainingTicks: currentExercise.restDuration,
      currentIntervalMs: intervalMs,
    );
  }

  void _startNewCycle(int intervalMs) {
    // Сигнал для визуального слоя: "Мы начали сначала" (нужен сброс rawPosition)
    _resetController.add(null);

    final stepData = _getCurrentStepData(0);

    state = BreathSessionState(
      status: BreathSessionStatus.breath,
      phase: stepData.phase,
      exerciseIndex: _exerciseIndex,
      remainingTicks: stepData.remainingTicks,
      currentIntervalMs: intervalMs,
    );
  }

  void _advanceExercise(int intervalMs) {
    _exerciseIndex++;

    if (_exerciseIndex >= session.exercises.length) {
      complete();
      return;
    }

    _resetCycleInternal();

    // Уведомляем о глобальной смене упражнения
    _resetController.add(null);

    final nextExercise = session.exercises[_exerciseIndex];

    // Если следующее упражнение - только отдых
    if (nextExercise.steps.isEmpty && nextExercise.restDuration > 0) {
      _startRest(intervalMs);
    } else {
      _startNewCycle(intervalMs);
    }
  }

  void _resetCycleInternal() {
    _cycleTick = 0;
    _repeatCounter = 0;
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
