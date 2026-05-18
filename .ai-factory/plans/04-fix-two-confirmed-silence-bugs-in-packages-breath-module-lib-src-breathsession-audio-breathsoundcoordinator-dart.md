# Plan: Fix two confirmed silence bugs in BreathSoundCoordinator

## Context
Two bugs in `BreathSoundCoordinator` silence the breath audio: the tick guard misses the `rest` status that sessions enter on start, and `setAsset` runs lazily on every phase switch which on Android takes longer than a 4-tick phase, so the fade-in never fires. Fix the tick guard and preload all phase loops once via `setAudioSources(...)`, then switch with `seek(Duration.zero, index: ...)` only.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Tick guard fix

- [x] **Task 1: Allow ticks during `BreathSessionStatus.rest`**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  In `_onTick()` widen the guard so ticks fire in three cases: `_currentStatus == BreathSessionStatus.pause`, `_currentStatus == BreathSessionStatus.rest`, or `_currentStatus == BreathSessionStatus.breath && _currentPhase == BreathPhase.rest`. Express the guard as a single boolean to avoid operator-precedence mistakes:

  ```dart
  final allowTick = _currentStatus == BreathSessionStatus.pause ||
      _currentStatus == BreathSessionStatus.rest ||
      (_currentStatus == BreathSessionStatus.breath &&
          _currentPhase == BreathPhase.rest);
  if (!allowTick) return;
  ```

  Keep the existing early-return when the player is null. No other behaviour changes.

### Phase 2: Preloaded playlist for breathing loops

- [x] **Task 2: Replace lazy `setAsset` with a preloaded playlist via `setAudioSources`** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Remove the per-switch `setAsset` and load all phase assets once at `initialize()` using the non-deprecated `AudioPlayer.setAudioSources` API (`ConcatenatingAudioSource` is `@Deprecated` in just_audio 0.10.5 and would re-introduce warnings that Task 3 must clear).

  - Keep the existing `_phaseAssets` map but also introduce a fixed-order list (e.g. `static const List<BreathPhase> _phaseOrder = [BreathPhase.inhale, BreathPhase.exhale, BreathPhase.hold]`) so each phase maps to a stable playlist index. `rest` is intentionally absent (silence).
  - Keep `_loopPlayer` as `AudioPlayer?`. Add a private field `Future<void>? _loadFuture` to track the initial playlist load so `_switchToPhase` can `await` it before issuing the first `seek`.
  - In `initialize()`, immediately after `_loopPlayer = AudioPlayer()`:
    1. `unawaited(_loopPlayer!.setLoopMode(LoopMode.one));` — keep the existing call. `LoopMode.one` loops the currently active playlist item, which is exactly what we want for per-phase looping.
    2. `unawaited(_loopPlayer!.setVolume(0.0));` — mute first so any platform default volume never leaks during load.
    3. Build the sources list `final sources = _phaseOrder.map((p) => AudioSource.asset(_phaseAssets[p]!)).toList();` and assign `_loadFuture = _loopPlayer!.setAudioSources(sources, preload: true);` then `unawaited(_loadFuture);` — fire-and-forget on init, but keep the future for the race guard below.
  - Rewrite `_switchToPhase(BreathPhase phase)`:
    - Bump `_switchGen` as today and capture the local `gen`.
    - If `_phaseAssets[phase]` is absent or the player is null, return.
    - Look up the index via `_phaseOrder.indexOf(phase)`; if `-1`, return.
    - `if (_loadFuture != null) { await _loadFuture; }` — guards against cold-start, mid-exercise resume (pause → breath with no rest), and any path that skips the 15s rest. Without this the `seek(..., index:)` below can hit a not-yet-ready playlist on slow Android devices and silently no-op or throw.
    - After the await, re-check `gen != _switchGen` or `_currentStatus != BreathSessionStatus.breath` and bail out if either changed.
    - `await player.setVolume(0.0);`
    - `await player.seek(Duration.zero, index: index);`
    - `await player.play();`
    - Bail-out checks identical to today after `play()` (`gen != _switchGen`, `_currentStatus != BreathSessionStatus.breath`).
    - `_fadeTo(1.0, const Duration(seconds: 2));`
  - Remove the `await player.stop()` + `await player.setAsset(asset)` calls — they are the source of the ExoPlayer re-init cost.
  - In `reset()` keep `player.stop()` and `player.setVolume(0.0)`; do **not** re-create the player or reload the playlist (the preloaded sources stay valid for the next session). Also keep `_currentPhase = null` and `_currentStatus = null` as today — this is an existing line; no new assignment is being added, just a no-op clarification so Phase 2 does not move it.
  - In `dispose()` leave the existing teardown as-is (disposing the player drops the playlist with it).
  - No changes needed in `_onStateChanged` — the existing call site `unawaited(_switchToPhase(state.phase))` works unchanged because `_switchToPhase` keeps the same signature.

### Phase 3: Sanity sweep

- [x] **Task 3: Verify imports and references compile** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Confirm the existing `package:just_audio/just_audio.dart` import already exposes `AudioSource` (no new import needed; `ConcatenatingAudioSource` is no longer referenced). Confirm `_phaseAssets` and `_phaseOrder` stay in sync (every key in `_phaseAssets` is present in `_phaseOrder` in the same intended order). Run `flutter analyze packages/breath_module` (using `/usr/local/bin/flutter`) and fix any warnings introduced by the change — in particular, no `deprecated_member_use` warnings should remain.
