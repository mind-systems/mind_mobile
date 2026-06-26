import 'BreathMotionEngine.dart';
import 'BreathShapeShifter.dart';
import '../Models/BreathSessionState.dart';
import '../BreathSessionViewModel.dart';

class BreathAnimationCoordinator {
  final BreathMotionEngine motionEngine;
  final BreathShapeShifter shapeShifter;
  final BreathViewModel viewModel;

  void Function()? _stateListener;

  int? _previousRemainingTicks;
  int? _previousPhaseIndex;
  bool _initialized = false;

  BreathAnimationCoordinator({
    required this.motionEngine,
    required this.shapeShifter,
    required this.viewModel,
  });

  void initialize(BreathSessionState initialState) {
    _stateListener = viewModel.listen(_onStateChanged);
    _syncInitialState(initialState);
  }

  void _syncInitialState(BreathSessionState state) {
    _previousRemainingTicks = state.remainingTicks;
    _previousPhaseIndex = state.currentPhaseIndex;

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
    motionEngine.setActive(state.lifecycle == BreathLifecycle.running && state.phase != BreathPhase.rest);
  }

  void _handleFirstReady(BreathSessionState state) {
    if (state.nextExerciseShape != null) {
      shapeShifter.morphToImmediate(state.nextExerciseShape!);
    }
    _initialized = true;
  }

  void _handleReset(BreathSessionState state) {
    // exerciseChange / rest: morph to the next exercise shape.
    // start / newCycle: initialize at the current exercise's shape by intent.
    final shape = (state.resetReason == ResetReason.exerciseChange ||
            state.resetReason == ResetReason.rest)
        ? state.nextExerciseShape
        : state.currentExerciseShape;

    if (shape != null) {
      shapeShifter.morphTo(shape);
    }

    // Скорость передаётся через границу цикла/смены упражнения (движение
    // перетекает в следующую итерацию). На старте сессии и при входе в отдых
    // точка стартует с нуля.
    final preserveVelocity = state.resetReason == ResetReason.newCycle ||
        state.resetReason == ResetReason.exerciseChange;
    motionEngine.resetPosition(0.0, preserveVelocity);

    if (state.totalPhases > 0) {
      motionEngine.setPhaseInfo(
        totalPhases: state.totalPhases,
        currentPhaseIndex: state.currentPhaseIndex,
      );
      motionEngine.setRemainingPhaseTicks(state.remainingTicks);
      _previousRemainingTicks = state.remainingTicks;
      _previousPhaseIndex = state.currentPhaseIndex;
    }

    motionEngine.setActive(state.lifecycle == BreathLifecycle.running && state.phase != BreathPhase.rest);
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
    final shouldBeActive = state.lifecycle == BreathLifecycle.running && state.phase != BreathPhase.rest;
    if (shouldBeActive != motionEngine.isActive) {
      if (shouldBeActive) {
        if (state.totalPhases > 0) {
          motionEngine.setPhaseInfo(
            totalPhases: state.totalPhases,
            currentPhaseIndex: state.currentPhaseIndex,
          );
          motionEngine.setRemainingPhaseTicks(state.remainingTicks);
          _previousRemainingTicks = state.remainingTicks;
          _previousPhaseIndex = state.currentPhaseIndex;
        } else {
          motionEngine.setRemainingPhaseTicks(0);
          _previousRemainingTicks = 0;
          _previousPhaseIndex = state.currentPhaseIndex;
        }
      }
      motionEngine.setActive(shouldBeActive);
    }

    // 2. Interval
    if (state.currentIntervalMs > 0) {
      motionEngine.setIntervalMs(state.currentIntervalMs);
    }

    // 3. Phase structure and remaining ticks
    if (state.lifecycle == BreathLifecycle.running && state.phase != BreathPhase.rest && state.totalPhases > 0) {
      motionEngine.setPhaseInfo(
        totalPhases: state.totalPhases,
        currentPhaseIndex: state.currentPhaseIndex,
      );

      // Re-arm phase duration on EITHER a remaining-tick change OR a phase
      // boundary. The phase-index check is essential: when two adjacent phases
      // share the same remaining-tick count at their boundary (e.g. inhale's
      // last tick remaining=1 collides with a 1-tick exhale's start remaining=1),
      // a remaining-only guard would skip setRemainingPhaseTicks, leaving the
      // engine linear-locked at the previous phase's velocity — so a shorter
      // phase never accelerates and the dot stalls short of its target.
      final phaseChanged = state.currentPhaseIndex != _previousPhaseIndex;
      if (state.remainingTicks != _previousRemainingTicks || phaseChanged) {
        motionEngine.setRemainingPhaseTicks(state.remainingTicks);
        _previousRemainingTicks = state.remainingTicks;
        _previousPhaseIndex = state.currentPhaseIndex;
      }
    } else {
      _previousRemainingTicks = state.remainingTicks;
      _previousPhaseIndex = state.currentPhaseIndex;
    }
  }

  void reset() {
    _previousRemainingTicks = null;
    _previousPhaseIndex = null;
    _initialized = false;
    motionEngine.setActive(false);
  }

  void dispose() {
    _stateListener?.call();
  }
}
