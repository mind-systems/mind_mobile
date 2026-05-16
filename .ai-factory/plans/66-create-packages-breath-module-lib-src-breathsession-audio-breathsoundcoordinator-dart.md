# Plan: Create `BreathSoundCoordinator`

## Context
Introduce a new audio coordinator inside `packages/breath_module` that plays looped inhale/hold/exhale ohm samples in sync with the breath session state machine, following the same lifecycle pattern as `BreathAnimationCoordinator`. This milestone delivers only the coordinator file itself — wiring into the screen and tick sounds are separate milestones (12.4 / 12.6).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Create the coordinator

- [x] **Task 1: Create directory and stub file**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Create the new `Audio/` folder alongside `Animation/` inside `packages/breath_module/lib/src/BreathSession/` and add an empty `BreathSoundCoordinator.dart` placeholder. Imports to add in subsequent tasks:
  - `dart:async` — `Timer`, `Timer.periodic`
  - `dart:math` — `max`
  - `package:just_audio/just_audio.dart` — `AudioPlayer`, `LoopMode`
  - `../Models/BreathSessionState.dart` — `BreathSessionState`, `BreathPhase`, `BreathSessionStatus`, `SessionLoadState`
  - `../BreathSessionViewModel.dart` — `BreathViewModel`

- [x] **Task 2: Declare class, constructor, fields, and asset map** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Declare `class BreathSoundCoordinator` with:
  - Final field `final BreathViewModel viewModel;`
  - Mutable fields: `late AudioPlayer _player;`, `void Function()? _stateListener;`, `BreathPhase? _currentPhase;`, `BreathSessionStatus? _currentStatus;`, `Timer? _fadeTimer;`
  - Static asset map:
    ```dart
    static const Map<BreathPhase, String> _phaseAssets = {
      BreathPhase.inhale: 'assets/audio/ohm_inhale.wav',
      BreathPhase.exhale: 'assets/audio/ohm_exhale.wav',
      BreathPhase.hold:   'assets/audio/ohm_hold.wav',
      // rest → silence (no entry)
    };
    ```
  - Constructor: `BreathSoundCoordinator({required this.viewModel});`
  Mirror the property order and formatting style of `BreathAnimationCoordinator` for consistency.

- [x] **Task 3: Implement `initialize`** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Add `void initialize(BreathSessionState initialState)`:
  - `_player = AudioPlayer();`
  - Fire-and-forget `_player.setLoopMode(LoopMode.one);` (ignore the returned `Future`).
  - `_stateListener = viewModel.listen(_onStateChanged);`
  Do **not** call any `_syncInitialState` helper — a session always opens in `BreathSessionStatus.pause`, so there is nothing to sync at init time. Leave `_currentPhase` and `_currentStatus` `null` so the first event in `_onStateChanged` triggers the appropriate transition.

- [x] **Task 4: Implement `_onStateChanged` state-routing logic** (depends on Task 3)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Add private `void _onStateChanged(BreathSessionState state)`. Order of checks (each branch returns once it handles the event):
  1. **Load gate** — if `state.loadState != SessionLoadState.ready` → `return;`
  2. **Status changes** — if `state.status != _currentStatus`:
     - Update `_currentStatus = state.status;`
     - On `BreathSessionStatus.pause` → `_fadeTo(0.0, const Duration(milliseconds: 200));`
     - On `BreathSessionStatus.breath` (resume) → `_fadeTo(1.0, const Duration(milliseconds: 200));`
     - On `BreathSessionStatus.complete` or `BreathSessionStatus.rest` → `_fadeTo(0.0, const Duration(milliseconds: 500));`
     - `return;`
  3. **Phase changes** — if `state.phase != _currentPhase`:
     - Update `_currentPhase = state.phase;`
     - If `_phaseAssets.containsKey(state.phase)` → `_switchToPhase(state.phase);`
     - Else (rest) → `_fadeTo(0.0, const Duration(milliseconds: 500));`
     - `return;`
  4. **End-of-phase fade-out trigger** — if `_currentStatus == BreathSessionStatus.breath` AND `_phaseAssets.containsKey(state.phase)` AND `0 < state.remainingTicks && state.remainingTicks <= 3`:
     - `final intervalMs = state.currentIntervalMs > 0 ? state.currentIntervalMs : 1000;`
     - `_fadeTo(0.0, Duration(milliseconds: state.remainingTicks * intervalMs));`
  Use `switch` on `state.status` or plain `if/else` — match the project's existing style in `BreathAnimationCoordinator`.

- [x] **Task 5: Implement `_switchToPhase` and `_fadeTo`** (depends on Task 4)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Add the two helpers:
  - `Future<void> _switchToPhase(BreathPhase phase) async` — invoked fire-and-forget by the caller (no `await` at the call site):
    ```dart
    final asset = _phaseAssets[phase];
    if (asset == null) return;
    await _player.stop();
    await _player.setAsset(asset);
    await _player.setVolume(0.0);
    await _player.play();
    _fadeTo(1.0, const Duration(seconds: 2));
    ```
  - `void _fadeTo(double target, Duration duration)`:
    ```dart
    _fadeTimer?.cancel();
    final startVolume = _player.volume;
    final steps = max(1, duration.inMilliseconds ~/ 16);
    var tick = 0;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      tick++;
      final t = (tick / steps).clamp(0.0, 1.0);
      final v = startVolume + (target - startVolume) * t;
      _player.setVolume(v);
      if (tick >= steps) {
        timer.cancel();
        _fadeTimer = null;
      }
    });
    ```
  Volume must be clamped to `[0.0, 1.0]` if `just_audio` requires it — the linear interpolation above already stays in range as long as `startVolume` and `target` are both in `[0.0, 1.0]`, which the call sites guarantee.

- [x] **Task 6: Implement `reset` and `dispose`** (depends on Task 5)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Add the two lifecycle methods:
  - `void reset()`:
    ```dart
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _player.stop();        // fire-and-forget
    _player.setVolume(0.0); // fire-and-forget
    _currentPhase = null;
    _currentStatus = null;
    ```
  - `void dispose()`:
    ```dart
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _stateListener?.call();
    _stateListener = null;
    _player.dispose();
    ```
  Match the position-in-class ordering of `BreathAnimationCoordinator` (public lifecycle methods first, private helpers below).

### Phase 2: Verify

- [x] **Task 7: Static analysis** (depends on Task 6)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  From inside `packages/breath_module/`, run `/usr/local/bin/flutter analyze` and fix any reported issues in the new file only (unused imports, missing `await` warnings for intentional fire-and-forget calls — use `unawaited(...)` from `dart:async` or a leading discard `// ignore: discarded_futures` if lints complain). Do not touch other files; wiring is out of scope for this milestone.
