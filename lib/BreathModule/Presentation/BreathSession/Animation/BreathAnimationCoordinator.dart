import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Animation/BreathMotionEngine.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Animation/BreathShapeShifter.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionViewModel.dart';

class BreathAnimationCoordinator {
  final BreathMotionEngine motionEngine;
  final BreathShapeShifter shapeShifter;
  final BreathViewModel viewModel;

  RemoveListener? _stateListener;
  StreamSubscription? _resetSubscription;

  int? _previousExerciseIndex;
  int? _previousRemainingTicks;

  BreathAnimationCoordinator({
    required this.motionEngine,
    required this.shapeShifter,
    required this.viewModel,
  });

  void initialize(BreathSessionState initialState) {
    _stateListener = viewModel.addListener(_onStateChanged);
    _resetSubscription = viewModel.resetStream.listen(_onReset);
    _syncInitialState(initialState);
  }

  void _syncInitialState(BreathSessionState state) {
    _previousExerciseIndex = state.exerciseIndex;
    _previousRemainingTicks = state.remainingTicks;

    if (viewModel.currentExercise.steps.isNotEmpty) {
      final phaseMeta = viewModel.getCurrentPhaseMeta();
      motionEngine.setPhaseInfo(
        totalPhases: phaseMeta.totalPhases,
        currentPhaseIndex: phaseMeta.currentPhaseIndex,
      );
      motionEngine.setRemainingPhaseTicks(state.remainingTicks);
    } else {
      motionEngine.setRemainingPhaseTicks(0);
    }
    motionEngine.setActive(state.status == BreathSessionStatus.breath);
  }

  void _onStateChanged(BreathSessionState state) {
    // 1. Активность
    final shouldBeActive = state.status == BreathSessionStatus.breath;
    if (shouldBeActive != motionEngine.isActive) {
      if (shouldBeActive) {
        if (viewModel.currentExercise.steps.isNotEmpty) {
          final phaseMeta = viewModel.getCurrentPhaseMeta();
          motionEngine.setPhaseInfo(
            totalPhases: phaseMeta.totalPhases,
            currentPhaseIndex: phaseMeta.currentPhaseIndex,
          );
          motionEngine.setRemainingPhaseTicks(state.remainingTicks);
          _previousRemainingTicks = state.remainingTicks;
        } else {
          motionEngine.setRemainingPhaseTicks(0);
          _previousRemainingTicks = 0;
        }
      }
      motionEngine.setActive(shouldBeActive);
    }

    // 2. Интервал
    if (state.currentIntervalMs > 0) {
      motionEngine.setIntervalMs(state.currentIntervalMs);
    }

    // 3. Структура фаз и оставшиеся тики в текущей фазе
    if (state.status == BreathSessionStatus.breath &&
        viewModel.currentExercise.steps.isNotEmpty) {
      final phaseMeta = viewModel.getCurrentPhaseMeta();
      motionEngine.setPhaseInfo(
        totalPhases: phaseMeta.totalPhases,
        currentPhaseIndex: phaseMeta.currentPhaseIndex,
      );

      if (state.remainingTicks != _previousRemainingTicks) {
        motionEngine.setRemainingPhaseTicks(state.remainingTicks);
        _previousRemainingTicks = state.remainingTicks;
      }
    } else {
      _previousRemainingTicks = state.remainingTicks;
    }

    // 4. Смена упражнения
    if (_previousExerciseIndex != state.exerciseIndex) {
      _previousExerciseIndex = state.exerciseIndex;
    }
  }

  void _onReset(ResetReason reason) {
    ExerciseSet? shapeSource;

    if (reason == ResetReason.exerciseChange || reason == ResetReason.rest) {
      shapeSource = viewModel.getNextExerciseWithShape();
    } else {
      shapeSource = viewModel.currentExercise;
    }

    if (shapeSource?.shape != null) {
      shapeShifter.morphTo(shapeSource!.shape!);
    }

    motionEngine.resetPosition(0.0);
  }

  void dispose() {
    _stateListener?.call();
    _resetSubscription?.cancel();
  }
}
