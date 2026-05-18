# Plan: Fix two crossfade bugs: missing first-cycle audio and residual silence gap

## Context
Two bugs in `BreathSoundCoordinator` cause audio dropouts during phase transitions: (1) only player A's `setAudioSources` future is tracked, so the first cycle (where B is `_inactiveLoop`) can be silent if B is still loading; (2) step-5 in `_onStateChanged` fades the active loop to 0.0 ~1 tick before the phase change, so by the time `_switchToPhase` triggers play+fade-in there is a brief silence window on every transition.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Guarantee both players are loaded before any phase switch (Bug 1)

- [x] **Task 1: Audit current `initialize()` and make `_loadFuture` track both players**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  In `initialize()` ensure the playlist load is awaited for BOTH `_loopPlayerA` and `_loopPlayerB` via a single combined future. The exact shape is:
  ```dart
  _loadFuture = Future.wait<void>([
    _loopPlayerA!.setAudioSources(sources, preload: true),
    _loopPlayerB!.setAudioSources(sources, preload: true),
  ]).then((_) {});
  ```
  Do NOT leave `_loopPlayerB!.setAudioSources(...)` as an unawaited fire-and-forget call with no future stored. `_switchToPhase` already does `await _loadFuture` before issuing `seek` on `_inactiveLoop`, so this single change is sufficient to guarantee that the first phase switch (where B is the inactive loop) does not silently no-op. If the code already has this shape, leave it; no other change is required for Bug 1.

### Phase 2: Eliminate the residual silence gap on phase transitions (Bug 2)

- [x] **Task 2: Delete step-5 from `_onStateChanged`** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Remove the entire "5. End-of-phase fade-out trigger" block from `_onStateChanged` — the block that checks `_currentStatus == BreathSessionStatus.breath && _phaseAssets.containsKey(state.phase) && state.remainingTicks == 1` and calls `_fadePlayer(_activeLoop!, 0.0, Duration(milliseconds: intervalMs))`. The fade-out of the outgoing player will now be issued from inside `_switchToPhase` concurrently with the fade-in of the incoming player, so the outgoing sound remains audible while the incoming one ramps up.

- [x] **Task 3: Add `fadeDuration` parameter to `_switchToPhase` and use it for the concurrent fades** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Change the signature of `_switchToPhase` from `Future<void> _switchToPhase(BreathPhase phase)` to `Future<void> _switchToPhase(BreathPhase phase, Duration fadeDuration)`. Inside `_switchToPhase`, after `await inactive.play()` and the active/inactive reference swap, replace the existing `const duration = Duration(seconds: 2);` plus the two `_fadePlayer(...)` calls with the same two concurrent fades using the new `fadeDuration` argument:
  ```dart
  _fadePlayer(_activeLoop!, 1.0, fadeDuration);
  _fadePlayer(_inactiveLoop!, 0.0, fadeDuration);
  ```
  Keep both fades fire-and-forget (no `await`) so they run in parallel. Keep the existing `_switchGen` and `_currentStatus` guards before the fades.

- [x] **Task 4: Update call sites in `_onStateChanged` to pass `fadeDuration` derived from `state.currentIntervalMs`** (depends on Task 3)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  There are two call sites that invoke `_switchToPhase` from `_onStateChanged`:
  1. Step 3 (status change → `BreathSessionStatus.breath`) — the branch where `_phaseAssets.containsKey(state.phase) && state.phase != _currentPhase`.
  2. Step 4 (phase change) — the branch where `_phaseAssets.containsKey(state.phase)`.

  Update BOTH to compute the duration from the current interval and pass it in. Use the same fallback the deleted step-5 used (`currentIntervalMs > 0 ? currentIntervalMs : 1000`) so the call is safe when the engine has not yet reported a positive interval. Example:
  ```dart
  final intervalMs = state.currentIntervalMs > 0 ? state.currentIntervalMs : 1000;
  unawaited(_switchToPhase(state.phase, Duration(milliseconds: intervalMs)));
  ```
  Do not change the `_fadePlayer(_activeLoop!, 0.0, ...)` direct calls in step-3 (`pause`, `complete`, `rest` branches) or in step-4's `else` branch (no asset for current phase) — per the milestone these transitions are unaffected.

### Phase 3: Verify no regressions

- [x] **Task 5: Re-read `_onStateChanged` and `_switchToPhase` end-to-end** (depends on Task 4)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Walk the file once more and confirm:
  - `_loadFuture` is `Future.wait` over both players.
  - Step-5 is gone (numbering of remaining comments may need a small touch-up but is not required).
  - `_switchToPhase` accepts `fadeDuration` and uses it for both concurrent fades.
  - Both `_switchToPhase` call sites pass a duration derived from `state.currentIntervalMs` with the `> 0 ? : 1000` fallback.
  - No other call sites or tests reference the old `_switchToPhase(BreathPhase)` single-arg signature; if any exist (e.g. in test doubles), update them too.
