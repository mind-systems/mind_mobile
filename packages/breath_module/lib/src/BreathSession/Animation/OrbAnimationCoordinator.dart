import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../CommonModels/SetShape.dart';
import '../Models/BreathSessionState.dart';
import '../BreathSessionViewModel.dart';

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

  bool _initialized = false;
  RemoveListener? _stateListener;

  // Interpolation
  late AnimationController _animController;
  double _previousProgress = _kMinProgress;
  double _targetProgress = _kMinProgress;
  final Curve _activeCurve = Curves.easeOut;

  OrbAnimationCoordinator({required this.viewModel, required this.vsync});

  // ===== Lifecycle =====

  void initialize(BreathSessionState initialState) {
    _animController = AnimationController(
      vsync: vsync,
      duration: const Duration(seconds: 1),
    )..addListener(_onAnimationTick);

    _stateListener = viewModel.addListener(_onStateChanged);

    if (initialState.loadState == SessionLoadState.ready) {
      _updateMaxProgress(initialState.nextExerciseShape);
    }
  }

  void _onAnimationTick() {
    final t = _activeCurve.transform(_animController.value);
    orbProgress.value = _lerp(_previousProgress, _targetProgress, t);
  }

  void _handleReset(BreathSessionState state) {
    final shape = (state.resetReason == ResetReason.exerciseChange ||
            state.resetReason == ResetReason.rest)
        ? state.nextExerciseShape
        : state.currentExerciseShape;

    _updateMaxProgress(shape);

    if (state.resetReason == ResetReason.rest) {
      // Snap to min — orb should be at minimum during rest, no animation needed.
      _animController.stop();
      _previousProgress = _kMinProgress;
      _targetProgress = _kMinProgress;
      orbProgress.value = _kMinProgress;
      return;
    }

    // exerciseChange / newCycle: start animation from enriched state fields.
    if (state.totalPhases > 0) {
      final phase = state.phase;
      if (phase == BreathPhase.inhale || phase == BreathPhase.exhale) {
        final total = state.currentPhaseTotalDuration;
        final remaining = state.remainingTicks;
        if (total > 0) {
          _startAnimation(phase: phase, total: total, remaining: remaining);
          return;
        }
      }
    }

    // Fallback: not in an animated phase — freeze.
    _animController.stop();
    _previousProgress = orbProgress.value;
    _targetProgress = orbProgress.value;
  }

  void _onStateChanged(BreathSessionState state) {
    if (state.loadState != SessionLoadState.ready) return;

    if (!_initialized) {
      _updateMaxProgress(state.nextExerciseShape);
      _initialized = true;
    }

    if (state.resetReason != null) {
      _handleReset(state);
      return;
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

    final total = state.currentPhaseTotalDuration;
    if (total <= 0) return;

    final remaining = state.remainingTicks;

    _startAnimation(phase: phase, total: total, remaining: remaining);
  }

  void _startAnimation({required BreathPhase phase, required int total, required int remaining}) {
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

  void reset() {
    _animController.stop();
    _previousProgress = _kMinProgress;
    _targetProgress = _kMinProgress;
    orbProgress.value = _kMinProgress;
    _initialized = false;
  }

  void dispose() {
    _animController.dispose();
    _stateListener?.call();
    orbProgress.dispose();
  }

  // ===== Helpers =====

  double _lerp(double a, double b, double t) => a + (b - a) * t;
}
