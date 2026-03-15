import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  int? _previousRemainingTicks;
  bool _initialized = false;

  BreathAnimationCoordinator({
    required this.motionEngine,
    required this.shapeShifter,
    required this.viewModel,
  });

  void initialize(BreathSessionState initialState) {
    _stateListener = viewModel.addListener(_onStateChanged);
    _syncInitialState(initialState);
  }

  void _syncInitialState(BreathSessionState state) {
    _previousRemainingTicks = state.remainingTicks;

    if (state.loadState != SessionLoadState.ready) {
      motionEngine.setActive(false);
      return;
    }

    if (state.totalPhases > 0) {
      motionEngine.setPhaseInfo(
        totalPhases: state.totalPhases,
        currentPhaseIndex: state.currentPhaseIndex,
      );
      motionEngine.setRemainingPhaseTicks(state.remainingTicks);
    } else {
      motionEngine.setRemainingPhaseTicks(0);
    }
    motionEngine.setActive(state.status == BreathSessionStatus.breath);
  }

  void _handleFirstReady(BreathSessionState state) {
    if (state.nextExerciseShape != null) {
      shapeShifter.morphToImmediate(state.nextExerciseShape!);
    }
    _initialized = true;
  }

  void _handleReset(BreathSessionState state) {
    if (kDebugMode) debugPrint('[BreathCoord] reset: ${state.resetReason}');

    final shape = (state.resetReason == ResetReason.exerciseChange ||
            state.resetReason == ResetReason.rest)
        ? state.nextExerciseShape
        : state.currentExerciseShape;

    if (shape != null) {
      shapeShifter.morphTo(shape);
    }

    motionEngine.resetPosition(0.0);

    if (state.totalPhases > 0) {
      motionEngine.setPhaseInfo(
        totalPhases: state.totalPhases,
        currentPhaseIndex: state.currentPhaseIndex,
      );
      motionEngine.setRemainingPhaseTicks(state.remainingTicks);
      _previousRemainingTicks = state.remainingTicks;
    }
  }

  void _onStateChanged(BreathSessionState state) {
    if (state.loadState != SessionLoadState.ready) return;

    if (!_initialized) {
      _handleFirstReady(state);
    }

    if (state.resetReason != null) {
      _handleReset(state);
      return;
    }

    // 1. Activity
    final shouldBeActive = state.status == BreathSessionStatus.breath;
    if (shouldBeActive != motionEngine.isActive) {
      if (shouldBeActive) {
        if (state.totalPhases > 0) {
          motionEngine.setPhaseInfo(
            totalPhases: state.totalPhases,
            currentPhaseIndex: state.currentPhaseIndex,
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

    // 2. Interval
    if (state.currentIntervalMs > 0) {
      motionEngine.setIntervalMs(state.currentIntervalMs);
    }

    // 3. Phase structure and remaining ticks
    if (state.status == BreathSessionStatus.breath && state.totalPhases > 0) {
      motionEngine.setPhaseInfo(
        totalPhases: state.totalPhases,
        currentPhaseIndex: state.currentPhaseIndex,
      );

      if (state.remainingTicks != _previousRemainingTicks) {
        motionEngine.setRemainingPhaseTicks(state.remainingTicks);
        _previousRemainingTicks = state.remainingTicks;
      }
    } else {
      _previousRemainingTicks = state.remainingTicks;
    }
  }

  /// Resets coordinator state caches after a session restart.
  ///
  /// Call this before [BreathViewModel.restart] so that the next
  /// ready-state triggers a full phaseInfo re-initialisation.
  void reset() {
    _previousRemainingTicks = null;
    _initialized = false;
    motionEngine.setActive(false);
  }

  void dispose() {
    _stateListener?.call();
  }
}
