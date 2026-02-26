import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionStateMachine.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionViewModel.dart';

class OrbAnimationCoordinator {
  final BreathViewModel viewModel;

  final ValueNotifier<double> orbProgress = ValueNotifier(_kMinProgress);

  // Progress range constants
  static const double _kMinProgress = 0.2;
  static const double _kMaxProgressCircle = 0.8;
  static const double _kMaxProgressOther = 1.0;

  // Internal state
  final double _minProgress = _kMinProgress;
  double _maxProgress = _kMaxProgressOther;

  bool _resetStreamSubscribed = false;
  RemoveListener? _stateListener;
  StreamSubscription? _resetSubscription;

  OrbAnimationCoordinator({required this.viewModel});

  // ===== Lifecycle =====

  void initialize(BreathSessionState initialState) {
    _stateListener = viewModel.addListener(_onStateChanged);
    _resetSubscription = viewModel.resetStream.listen(_onReset);

    if (initialState.loadState == SessionLoadState.ready) {
      _updateMaxProgress(viewModel.getNextExerciseWithShape()?.shape);
    }
  }

  void _onStateChanged(BreathSessionState state) {
    if (state.loadState != SessionLoadState.ready) return;

    // Re-subscribe to resetStream on first ready state (same pattern as
    // BreathAnimationCoordinator) because the stream may be empty at
    // initialize() time due to async engine setup.
    if (!_resetStreamSubscribed) {
      _resetSubscription?.cancel();
      _resetSubscription = viewModel.resetStream.listen(_onReset);
      _resetStreamSubscribed = true;

      _updateMaxProgress(viewModel.getNextExerciseWithShape()?.shape);
    }

    if (state.status != BreathSessionStatus.breath) return;

    final phase = state.phase;
    if (phase != BreathPhase.inhale && phase != BreathPhase.exhale) return;

    // Compute phaseRaw = (total - remaining) / total
    final phaseMeta = viewModel.getCurrentPhaseMeta();
    final currentPhaseIndex = phaseMeta.currentPhaseIndex;
    final exercise = viewModel.currentExercise;

    if (exercise.steps.isEmpty || currentPhaseIndex >= exercise.steps.length) {
      return;
    }

    final total = exercise.steps[currentPhaseIndex].duration;
    if (total <= 0) return;

    final remaining = state.remainingTicks;
    final phaseRaw = (total - remaining) / total;

    final double progress;
    if (phase == BreathPhase.inhale) {
      progress = _lerp(_minProgress, _maxProgress, phaseRaw.clamp(0.0, 1.0));
    } else {
      progress = _lerp(_minProgress, _maxProgress, (1.0 - phaseRaw).clamp(0.0, 1.0));
    }

    orbProgress.value = progress;
  }

  void _onReset(ResetReason reason) {
    final shapeSource = (reason == ResetReason.exerciseChange || reason == ResetReason.rest)
        ? viewModel.getNextExerciseWithShape()
        : viewModel.currentExercise;

    _updateMaxProgress(shapeSource?.shape);

    orbProgress.value = _minProgress;
  }

  void _updateMaxProgress(SetShape? shape) {
    _maxProgress = (shape == SetShape.circle) ? _kMaxProgressCircle : _kMaxProgressOther;
  }

  // ===== Controls =====

  /// Resets coordinator state after a session restart.
  ///
  /// Call this before [BreathViewModel.restart] so that the next
  /// ready-state triggers a full re-initialisation.
  void reset() {

    _resetStreamSubscribed = false;
    orbProgress.value = _kMinProgress;
  }

  void dispose() {
    _stateListener?.call();
    _resetSubscription?.cancel();
    orbProgress.dispose();
  }

  // ===== Helpers =====

  double _lerp(double a, double b, double t) => a + (b - a) * t;
}
