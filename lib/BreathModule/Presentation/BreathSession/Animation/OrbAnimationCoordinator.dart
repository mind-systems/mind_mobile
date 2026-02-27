import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/Models/BreathSessionState.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionStateMachine.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionViewModel.dart';

class OrbAnimationCoordinator {
  final BreathViewModel viewModel;
  final TickerProvider vsync;

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

  // Interpolation
  late AnimationController _animController;
  double _previousProgress = _kMinProgress;
  double _targetProgress = _kMinProgress;
  final Curve _activeCurve = Curves.easeOut;

  // State machine emits twice per tick (intervalMs update + phase/remaining),
  // so deduplicate on (phase, remaining) to avoid restarting the animation
  // before easeOut has had a chance to move orbProgress.
  int? _lastAnimatedRemaining;
  BreathPhase? _lastAnimatedPhase;

  OrbAnimationCoordinator({required this.viewModel, required this.vsync});

  // ===== Lifecycle =====

  void initialize(BreathSessionState initialState) {
    _animController = AnimationController(
      vsync: vsync,
      duration: const Duration(seconds: 1),
    )..addListener(_onAnimationTick);

    _stateListener = viewModel.addListener(_onStateChanged);
    _resetSubscription = viewModel.resetStream.listen(_onReset);

    if (initialState.loadState == SessionLoadState.ready) {
      _updateMaxProgress(viewModel.getNextExerciseWithShape()?.shape);
    }
  }

  void _onAnimationTick() {
    final t = _activeCurve.transform(_animController.value);
    orbProgress.value = _lerp(_previousProgress, _targetProgress, t);
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

    // Non-breath status (pause, complete, idle) — freeze orb at current position.
    if (state.status != BreathSessionStatus.breath) {
      _animController.stop();
      return;
    }

    final phase = state.phase;

    // Non-animated phases (hold, rest) — freeze orb at current position.
    if (phase != BreathPhase.inhale && phase != BreathPhase.exhale) {
      _animController.stop();
      return;
    }

    final phaseMeta = viewModel.getCurrentPhaseMeta();
    final currentPhaseIndex = phaseMeta.currentPhaseIndex;
    final exercise = viewModel.currentExercise;

    if (exercise.steps.isEmpty || currentPhaseIndex >= exercise.steps.length) return;

    final total = exercise.steps[currentPhaseIndex].duration;
    if (total <= 0) return;

    final remaining = state.remainingTicks;

    // Skip duplicate emits — see _lastAnimatedRemaining field comment above.
    if (remaining == _lastAnimatedRemaining && phase == _lastAnimatedPhase) return;
    _lastAnimatedRemaining = remaining;
    _lastAnimatedPhase = phase;

    _startAnimation(phase: phase, total: total, remaining: remaining);
  }

  void _onReset(ResetReason reason) {
    final shapeSource = (reason == ResetReason.exerciseChange || reason == ResetReason.rest)
        ? viewModel.getNextExerciseWithShape()
        : viewModel.currentExercise;

    _updateMaxProgress(shapeSource?.shape);

    if (reason == ResetReason.rest) {
      // Snap to min — orb should be at minimum during rest, no animation needed.
      _animController.stop();
      _previousProgress = _kMinProgress;
      _targetProgress = _kMinProgress;
      orbProgress.value = _kMinProgress;
      return;
    }

    // exerciseChange / newCycle: re-sync animation immediately from fresh
    // ViewModel state rather than waiting for the next _onStateChanged.
    //
    // Root cause (todo: fix properly): _onStateChanged fires synchronously via
    // the Riverpod listener with stale data *before* this broadcast-stream
    // callback arrives. By the time _onReset runs the ViewModel already holds
    // the new cycle's state, so we start the animation here with fresh data and
    // poison the dedup cache (_lastAnimatedRemaining) so that the stale
    // _onStateChanged emit that follows is ignored.
    //
    // BreathAnimationCoordinator._onReset has the same workaround for the same
    // reason — any fix here should be applied there too, and vice versa.
    if (viewModel.currentExercise.steps.isNotEmpty) {
      final phase = viewModel.getCurrentPhaseInfo().phase;
      final phaseMeta = viewModel.getCurrentPhaseMeta();
      final currentPhaseIndex = phaseMeta.currentPhaseIndex;
      final exercise = viewModel.currentExercise;

      if ((phase == BreathPhase.inhale || phase == BreathPhase.exhale) &&
          currentPhaseIndex < exercise.steps.length) {
        final total = exercise.steps[currentPhaseIndex].duration;
        final remaining = viewModel.getCurrentPhaseInfo().remainingInPhase;

        if (total > 0) {
          _lastAnimatedRemaining = remaining;
          _lastAnimatedPhase = phase;
          _startAnimation(phase: phase, total: total, remaining: remaining);
          return;
        }
      }
    }

    // Fallback: not in an animated phase — freeze and clear dedup cache.
    _animController.stop();
    _previousProgress = orbProgress.value;
    _targetProgress = orbProgress.value;
    _lastAnimatedRemaining = null;
    _lastAnimatedPhase = null;
  }

  void _startAnimation({required BreathPhase phase, required int total, required int remaining}) {
    // Target remaining-1 so the animation starts moving on tick 0 of the phase,
    // not the second tick (tick 0 would otherwise compute phaseRaw=0 → no movement).
    final nextRemaining = (remaining - 1).clamp(0, total);
    final phaseRaw = (total - nextRemaining) / total;

    final double progress;
    if (phase == BreathPhase.inhale) {
      progress = _lerp(_minProgress, _maxProgress, phaseRaw.clamp(0.0, 1.0));
    } else {
      progress = _lerp(_minProgress, _maxProgress, (1.0 - phaseRaw).clamp(0.0, 1.0));
    }

    _animController.stop();
    _previousProgress = orbProgress.value;
    _targetProgress = progress;
    _animController
      ..value = 0.0
      ..forward();
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
    _animController.stop();
    _previousProgress = _kMinProgress;
    _targetProgress = _kMinProgress;
    orbProgress.value = _kMinProgress;
    _resetStreamSubscribed = false;
    _lastAnimatedRemaining = null;
    _lastAnimatedPhase = null;
  }

  void dispose() {
    _animController.dispose();
    _stateListener?.call();
    _resetSubscription?.cancel();
    orbProgress.dispose();
  }

  // ===== Helpers =====

  double _lerp(double a, double b, double t) => a + (b - a) * t;
}
