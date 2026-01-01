import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/Models/BreathExercise.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/Views/BreathWidget.dart';

class TickData {
  final int intervalMs; // Время в миллисекундах с предыдущего тика

  TickData(this.intervalMs);
}

abstract class ITickService {
  Stream<TickData> get tickStream;
}

enum BreathSessionStatus { pause, breath, rest, complete }
enum BreathPhase { inhale, holdIn, exhale, holdOut, rest }

class _PhaseInfo {
  final BreathPhase phase;
  final int duration;

  _PhaseInfo(this.phase, this.duration);
}

// Базовый провайдер для BreathViewModel (переопределяется в модуле)
final breathViewModelProvider = StateNotifierProvider<BreathViewModel, BreathSessionState>((ref) {
  throw UnimplementedError('BreathViewModel должен быть передан через override в BreathModule');
});


class BreathViewModel extends StateNotifier<BreathSessionState> {
  final ITickService tickService;
  final BreathSession session;
  late final BreathShapeController shapeController;

  StreamSubscription<TickData>? _subscription;

  // Текущее состояние сессии
  int exerciseIndex = 0; // todo: это и "final BreathSession session" сверху - публичные поля и вьюшка их трогает, а не должна бы.
  int _repeatCounter = 0;
  int _cycleTick = 0;
  int _restTick = 0;

  late BreathExercise _currentExercise;
  List<_PhaseInfo> _phases = [];

  BreathViewModel({
    required this.tickService,
    required this.session,
  }) : super(BreathSessionState.initial()) {
    shapeController = BreathShapeController();
    _currentExercise = session.exercises.first;
    _buildPhases();
  }

  // ===== Lifecycle =====

  void start() {
    state = state.copyWith(status: BreathSessionStatus.breath);
    _subscription = tickService.tickStream.listen(_onTick);
  }

  void pause() {
    if (state.status != BreathSessionStatus.complete) {
      state = state.copyWith(status: BreathSessionStatus.pause);
    }
  }

  void resume() {
    if (state.status == BreathSessionStatus.pause) {
      // Определяем, были ли мы в отдыхе или в дыхании
      final wasResting = _restTick > 0;
      state = state.copyWith(
        status: wasResting ? BreathSessionStatus.rest : BreathSessionStatus.breath,
      );
    }
  }

  void skipToNextExercise() {
    _resetCycle();
    _advanceExercise();
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
        // Игнорируем тики в паузе
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

    // Проверяем завершение цикла
    if (_cycleTick >= _currentExercise.cycleDuration) {
      _cycleTick = 0;
      _repeatCounter++;

      // Проверяем завершение всех повторений
      if (_repeatCounter >= _currentExercise.repeatCount) {
        _repeatCounter = 0;

        // Переходим к отдыху или следующему упражнению
        if (_currentExercise.restDuration > 0) {
          _startRest();
        } else {
          _advanceExercise();
        }
        return;
      }
    }

    // Определяем текущую фазу и оставшиеся тики
    final phaseData = _getCurrentPhaseData(_cycleTick);

    // Рассчитываем целевой прогресс
    final targetProgress = _mapTickToProgress(_cycleTick);

    // Анимируем к целевому прогрессу с длительностью = интервал между тиками
    shapeController.animateToProgress(
      targetProgress,
      Duration(milliseconds: intervalMs),
    );

    // Обновляем состояние
    state = BreathSessionState(
      status: BreathSessionStatus.breath,
      phase: phaseData.phase,
      remainingTicks: phaseData.remainingTicks,
      shapeProgress: targetProgress,
    );
  }

  void _onRestTick(int intervalMs) {
    _restTick++;

    final restDuration = _currentExercise.restDuration;
    final remainingTicks = restDuration - _restTick;

    if (_restTick >= restDuration) {
      _restTick = 0;
      _advanceExercise();
      return;
    }

    // Прогресс фигуры не меняется во время отдыха
    state = BreathSessionState(
      status: BreathSessionStatus.rest,
      phase: BreathPhase.rest,
      remainingTicks: remainingTicks,
      shapeProgress: state.shapeProgress,
    );
  }

  // ===== Phase calculation =====

  ({BreathPhase phase, int remainingTicks}) _getCurrentPhaseData(int tick) {
    int accumulated = 0;

    for (final phaseInfo in _phases) {
      if (tick < accumulated + phaseInfo.duration) {
        final remaining = accumulated + phaseInfo.duration - tick;
        return (phase: phaseInfo.phase, remainingTicks: remaining);
      }
      accumulated += phaseInfo.duration;
    }

    return (phase: _phases.last.phase, remainingTicks: 0);
  }

  void _buildPhases() {
    _phases = [];

    _phases.add(_PhaseInfo(BreathPhase.inhale, _currentExercise.breathInDuration));

    if (_currentExercise.holdInDuration > 0) {
      _phases.add(_PhaseInfo(BreathPhase.holdIn, _currentExercise.holdInDuration));
    }

    _phases.add(_PhaseInfo(BreathPhase.exhale, _currentExercise.breathOutDuration));

    if (_currentExercise.holdOutDuration > 0) {
      _phases.add(_PhaseInfo(BreathPhase.holdOut, _currentExercise.holdOutDuration));
    }
  }

  // ===== Progress mapping =====

  double _mapTickToProgress(int tick) {
    final total = _currentExercise.cycleDuration;
    if (total == 0) return 0.0;

    // Для круга - простая линейная зависимость
    if (_currentExercise.shape == BreathShape.circle) {
      return tick / total;
    }

    // Для квадрата и треугольника - распределяем по сегментам
    final segmentSize = 1.0 / _phases.length;
    double cursor = 0.0;
    int remainingTick = tick;

    for (final phase in _phases) {
      if (remainingTick < phase.duration) {
        return cursor + (remainingTick / phase.duration) * segmentSize;
      }
      remainingTick -= phase.duration;
      cursor += segmentSize;
    }

    return 1.0;
  }

  // ===== Exercise switching =====

  void _startRest() {
    _restTick = 0;
    state = state.copyWith(
      status: BreathSessionStatus.rest,
      remainingTicks: _currentExercise.restDuration,
    );
  }

  void _advanceExercise() {
    exerciseIndex++;

    if (exerciseIndex >= session.exercises.length) {
      complete();
      return;
    }

    _currentExercise = session.exercises[exerciseIndex];
    _buildPhases();
    _resetCycle();

    state = state.copyWith(status: BreathSessionStatus.breath);
  }

  void _resetCycle() {
    _cycleTick = 0;
    _repeatCounter = 0;
    _restTick = 0;
    shapeController.setProgressImmediately(0.0);
  }
}

// Расширение для copyWith
extension BreathSessionStateExtension on BreathSessionState {
  BreathSessionState copyWith({
    BreathSessionStatus? status,
    BreathPhase? phase,
    int? remainingTicks,
    double? shapeProgress,
  }) {
    return BreathSessionState(
      status: status ?? this.status,
      phase: phase ?? this.phase,
      remainingTicks: remainingTicks ?? this.remainingTicks,
      shapeProgress: shapeProgress ?? this.shapeProgress,
    );
  }
}
