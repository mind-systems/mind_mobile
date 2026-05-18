# Plan: Fix step-5 in `_onStateChanged` firing too early and cancelling fade-in

## Context
After milestone 12.7 introduced the preloaded playlist, `_switchToPhase` correctly calls `_fadeTo(1.0, 2s)` when the phase starts. However, step 5 in `_onStateChanged` (the end-of-phase fade-out trigger) fires at `remainingTicks <= 3`, which means roughly 1 second after the phase begins on a typical 4-tick phase. This cancels the 2 s fade-in before the volume becomes audible, so breathing phases remain silent. The fix narrows the trigger to fire only on the very last tick.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Adjust end-of-phase fade-out condition

- [x] **Task 1: Narrow step-5 trigger in `_onStateChanged` and simplify fade duration**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  In the step-5 block of `_onStateChanged` (the "End-of-phase fade-out trigger" branch, currently lines ~139–145):
  - Replace the condition `state.remainingTicks > 0 && state.remainingTicks <= 3` with a single check `state.remainingTicks == 1`. Keep the other conditions in the `if` (`_currentStatus == BreathSessionStatus.breath` and `_phaseAssets.containsKey(state.phase)`) unchanged.
  - Simplify the fade duration: replace `Duration(milliseconds: state.remainingTicks * intervalMs)` with `Duration(milliseconds: intervalMs)`. The `intervalMs` fallback expression (`state.currentIntervalMs > 0 ? state.currentIntervalMs : 1000`) stays.
  - Net effect: the fade-out is scheduled exactly once per phase, on the final tick, with a duration equal to one tick interval, so the 2 s fade-in started by `_switchToPhase` runs uninterrupted earlier in the phase.
  - No other methods or fields change. Do not touch `_switchToPhase`, `_onTick`, `initialize`, `reset`, or `dispose`.
