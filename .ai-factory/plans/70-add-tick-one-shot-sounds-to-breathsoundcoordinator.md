# Plan: Add tick one-shot sounds to `BreathSoundCoordinator`

## Context
Extend `BreathSoundCoordinator` so it plays a one-shot tick sound on every tick during `pause` status and during the `rest` phase while breathing. The sound asset is picked per `TickSource` from `state.tickSource` (timer → `tick_clock.wav`, heartbeat → `tick_heartbeat.wav`). Asset is pre-loaded on a dedicated `AudioPlayer` so each tick only seeks-and-plays. Prerequisite milestone 12.5 (tick source on state) is already merged; audio files already exist in `assets/audio/` and `assets/audio/` is already declared in `pubspec.yaml`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Add tick player infrastructure

- [x] **Task 1: Add tick player fields and asset map**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Inside `class BreathSoundCoordinator`:
  - Rename the existing `AudioPlayer? _player` field to `AudioPlayer? _loopPlayer` (keeps the existing loop-playback semantics clear vs the new tick player). Update all references in `initialize`, `reset`, `dispose`, `_switchToPhase`, and `_fadeTo` accordingly — no behavior change.
  - Add new fields:
    ```dart
    late AudioPlayer _tickPlayer;
    StreamSubscription<void>? _tickSub;
    TickSource _currentTickSource = TickSource.timer;
    ```
  - Add a static tick asset map next to `_phaseAssets`:
    ```dart
    static const Map<TickSource, String> _tickAssets = {
      TickSource.timer:     'assets/audio/tick_clock.wav',
      TickSource.heartbeat: 'assets/audio/tick_heartbeat.wav',
    };
    ```
  - Add the import for `TickSource` from `../../CommonModels/TickSource.dart` (path relative to `Audio/`).

- [x] **Task 2: Add `_loadTickAsset` helper and `_onTick` handler**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Add two private methods alongside `_switchToPhase` / `_fadeTo`:
  - `Future<void> _loadTickAsset(TickSource source) async { await _tickPlayer.setAsset(_tickAssets[source]!); }` — fire-and-forget at call sites via `unawaited(_loadTickAsset(...))`. Pre-buffers the asset so each tick only needs seek + play.
  - `void _onTick()`:
    - Guard: return early **unless** one of these is true:
      - `_currentStatus == BreathSessionStatus.pause`, OR
      - `_currentStatus == BreathSessionStatus.breath && _currentPhase == BreathPhase.rest`.
    - Otherwise: `unawaited(_tickPlayer.seek(Duration.zero).then((_) => _tickPlayer.play()));` — seek-then-play so we restart the pre-buffered asset every tick.

### Phase 2: Wire lifecycle (initialize / reset / dispose / state sync)

- [x] **Task 3: Initialize the tick player and subscribe to `tickStream`** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  In `initialize(BreathSessionState initialState)`, after the existing `_loopPlayer = AudioPlayer(); unawaited(_loopPlayer!.setLoopMode(LoopMode.one));` block and **before** attaching the state listener:
  - Sync the initial tick source from the passed-in state: `_currentTickSource = initialState.tickSource;`
  - Create the tick player and pre-load its asset:
    ```dart
    _tickPlayer = AudioPlayer();
    unawaited(_loadTickAsset(_currentTickSource));
    ```
  - Attach the tick subscription:
    ```dart
    _tickSub = viewModel.tickStream.listen((_) => _onTick());
    ```
  Keep the existing `_stateListener = viewModel.listen(_onStateChanged);` line as the last setup step.

- [x] **Task 4: React to tick-source changes in `_onStateChanged`** (depends on Task 3)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  In `_onStateChanged(BreathSessionState state)`, immediately after the load-state gate (`if (state.loadState != SessionLoadState.ready) return;`) and **before** the status-change branch, add:
  ```dart
  if (state.tickSource != _currentTickSource) {
    _currentTickSource = state.tickSource;
    unawaited(_loadTickAsset(_currentTickSource));
  }
  ```
  Per milestone 12.5, `tickSource` is stable within a session and only changes when the engine is rebuilt — this branch will normally not fire mid-session but is required for correctness across restarts.

- [x] **Task 5: Stop tick player on `reset()` and dispose in `dispose()`** (depends on Task 3)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  - In `reset()`: after the existing `_loopPlayer` stop/volume reset, add `unawaited(_tickPlayer.stop());`. **Do not** cancel `_tickSub` — ticks must continue firing after a session restart.
  - In `dispose()`: before/after the existing player teardown, add:
    ```dart
    _tickSub?.cancel();
    _tickSub = null;
    unawaited(_tickPlayer.dispose());
    ```
    Order: cancel the subscription first so no late tick fires after the player is disposed.
