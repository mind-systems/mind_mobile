# Plan: Adaptive crossfade duration based on incoming phase length

## Context
Replace the fixed `currentIntervalMs` crossfade duration in `BreathSoundCoordinator._onStateChanged` with a power-curve formula derived from the total length of the incoming phase, so short phases fade quickly and long phases get a fuller crossfade.

**Note on the milestone's reference table:** the milestone description quotes "1s → ~160ms, 2s → ~310ms, 3s → ~680ms, 4s → ~1000ms, 8s+ → 1500ms" and constants `k = 3.83`, exponent `0.65`, clamp `[150, 1500]`. Plugging the constants into the formula does **not** produce the quoted table — actual values are 1s → 341ms, 2s → 536ms, 3s → 706ms, 4s → 843ms, 8s → 1320ms, cap (1500ms) is reached near 10.5s. The constants are the executable source of truth (they're named static fields tuned in code), so the plan keeps `k = 3.83` and writes the **accurate** table in the source comment. If the perceptual intent really is the original table (1s ≈ 160ms, 4s ≈ 1000ms), `k` and the exponent need to be re-tuned — flag this to the user during implementation if it surfaces.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Implementation

- [x] **Task 1: Add tuning constants to `BreathSoundCoordinator`**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Add three `static const` fields near the top of the class, alongside `_phaseAssets` / `_phaseOrder` / `_tickAssets`:
  - `static const double _kFadeCoeff = 3.83;`
  - `static const int _kMinFadeMs = 150;`
  - `static const int _kMaxFadeMs = 1500;`
  Add a short comment above the constants explaining the curve: `fadeMs = (k * pow(nextPhaseMs, 0.65)).clamp(min, max)`. Include the **actual** reference table produced by these constants so future tuners aren't misled:
  - 1s phase → 341ms
  - 2s phase → 536ms
  - 3s phase → 706ms
  - 4s phase → 843ms
  - 8s phase → 1320ms
  - ~10.5s+ phase → 1500ms (capped)

- [x] **Task 2: Add a helper that computes adaptive fade duration**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Add a private helper on `BreathSoundCoordinator`:
  ```dart
  Duration _computeFadeDuration(BreathSessionState state) {
    final intervalMs = state.currentIntervalMs > 0 ? state.currentIntervalMs : 1000;
    final phaseTicks = state.currentPhaseTotalDuration;
    // Guard: if phase length is unknown/non-positive, fall back to one tick interval.
    if (phaseTicks <= 0) {
      return Duration(milliseconds: intervalMs.clamp(_kMinFadeMs, _kMaxFadeMs));
    }
    final nextPhaseMs = phaseTicks * intervalMs;
    final raw = _kFadeCoeff * pow(nextPhaseMs.toDouble(), 0.65);
    final clamped = raw.clamp(_kMinFadeMs.toDouble(), _kMaxFadeMs.toDouble()).toInt();
    return Duration(milliseconds: clamped);
  }
  ```
  `pow` is already imported via `dart:math` (line 2). Do not modify `_switchToPhase`'s signature.

- [x] **Task 3: Use adaptive duration at the two `_switchToPhase` call sites** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  In `_onStateChanged`:
  - Step 3 (status change, `BreathSessionStatus.breath` branch, ~line 153–156): drop the local `intervalMs` calc, compute `final fadeDuration = _computeFadeDuration(state);` and pass `fadeDuration` to `_switchToPhase`.
  - Step 4 (phase change, ~line 172–174): same — drop the local `intervalMs` calc and pass `_computeFadeDuration(state)` to `_switchToPhase`.
  Leave the other `_fadePlayer` calls in `_onStateChanged` (pause/rest/complete/non-phase-asset branches) unchanged — those use fixed durations by design.

- [x] **Task 4: Append the adaptive fade duration to the step-3 and step-4 debug logs** (depends on Task 3)

  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Unconditionally extend the two existing `debugPrint` lines in `_onStateChanged`:
  - Line ~148 (status-change log inside step 3): append ` fade=${fadeDuration.inMilliseconds}ms` to the printed string when entering the `BreathSessionStatus.breath` branch (move the `debugPrint` if needed so `fadeDuration` is in scope, or add a second `debugPrint` inside the branch immediately before the `_switchToPhase` call).
  - Line ~171 (phase-change log inside step 4): same — append ` fade=${fadeDuration.inMilliseconds}ms` to the existing log, placing it after `fadeDuration` is computed.
  `_switchToPhase` already prints `fadeDuration=...ms` at line 203, so this is purely a convenience for log grepping at the call site.
