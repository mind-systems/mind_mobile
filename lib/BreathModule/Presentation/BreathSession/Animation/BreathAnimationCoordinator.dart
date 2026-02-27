import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathExerciseDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Animation/BreathMotionEngine.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Animation/BreathShapeShifter.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionViewModel.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionStateMachine.dart';

class BreathAnimationCoordinator {
  final BreathMotionEngine motionEngine;
  final BreathShapeShifter shapeShifter;
  final BreathViewModel viewModel;

  RemoveListener? _stateListener;
  StreamSubscription? _resetSubscription;

  int? _previousExerciseIndex;
  int? _previousRemainingTicks;

  // Engine создаётся асинхронно в ViewModel.initState(), поэтому при initialize()
  // resetStream может быть пустым. Переподписываемся при первом ready-состоянии.
  bool _resetStreamSubscribed = false;

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

    if (state.loadState != SessionLoadState.ready) {
      motionEngine.setActive(false);
      return;
    }

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
    if (state.loadState != SessionLoadState.ready) return;

    if (!_resetStreamSubscribed) {
      _resetSubscription?.cancel();
      _resetSubscription = viewModel.resetStream.listen(_onReset);
      _resetStreamSubscribed = true;
    }

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
    BreathExerciseDTO? shapeSource;

    if (reason == ResetReason.exerciseChange || reason == ResetReason.rest) {
      shapeSource = viewModel.getNextExerciseWithShape();
    } else {
      shapeSource = viewModel.currentExercise;
    }

    if (shapeSource?.shape != null) {
      shapeShifter.morphTo(shapeSource!.shape!);
    }

    motionEngine.resetPosition(0.0);

    // Re-sync phase structure immediately after position reset.
    //
    // Root cause (todo: fix properly): _onStateChanged fires synchronously via
    // the Riverpod listener and processes stale remaining-ticks *before* this
    // broadcast-stream callback arrives. By the time _onReset runs the ViewModel
    // already holds the new cycle's state, so we re-sync the motion engine here
    // with the correct position=0.0 and fresh remaining ticks.
    //
    // OrbAnimationCoordinator._onReset has the same workaround for the same
    // reason — any fix here should be applied there too, and vice versa.
    if (viewModel.currentExercise.steps.isNotEmpty) {
      final phaseMeta = viewModel.getCurrentPhaseMeta();
      motionEngine.setPhaseInfo(
        totalPhases: phaseMeta.totalPhases,
        currentPhaseIndex: phaseMeta.currentPhaseIndex,
      );
      final phaseInfo = viewModel.getCurrentPhaseInfo();
      motionEngine.setRemainingPhaseTicks(phaseInfo.remainingInPhase);
      _previousRemainingTicks = phaseInfo.remainingInPhase;
    }
  }

  /// Resets coordinator state caches after a session restart.
  ///
  /// Call this before [BreathViewModel.restart] so that the next
  /// ready-state triggers a full phaseInfo re-initialisation.
  void reset() {
    _previousRemainingTicks = null;
    _previousExerciseIndex = null;
    _resetStreamSubscribed = false;
    motionEngine.setActive(false);
  }

  void dispose() {
    _stateListener?.call();
    _resetSubscription?.cancel();
  }
}
