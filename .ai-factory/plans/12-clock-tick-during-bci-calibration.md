# Plan: Clock tick during BCI calibration

## Context
Play a once-per-second clock tick while BCI calibration is in progress, giving the user (eyes closed, no other feedback) an audible signal that calibration is running. The tick stops on completion, failure, or disconnect.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Tick sound during calibration

- [x] **Task 1: Add tick player + timer fields and load the asset in initState**
  Files: `packages/bci_module/lib/src/BciPairing/Views/BciCalibrationSection.dart`
  In `_BciCalibrationSectionState`, add two fields alongside the existing `_completionCue`:
  ```dart
  late final AudioOneShot _tick;
  Timer? _tickTimer;
  ```
  In `initState`, after the existing `unawaited(_loadCue())`, instantiate and load the tick player fire-and-forget. **Mirror the existing `_loadCue()` pattern** (use `AssetAudioCatalog().sourceFor(AudioTrack(...))`) rather than the raw `AudioSource.asset(...)` snippet in the spec note, to stay consistent with the file's existing style. The tick asset lives in the **root app** at `assets/audio/tick_clock.ogg` (not under `packages/bci_module/assets/`), so use that exact path:
  ```dart
  _tick = AudioOneShot();
  unawaited(_loadTick());
  ```
  Add a `_loadTick()` helper next to `_loadCue()`:
  ```dart
  Future<void> _loadTick() async {
    final source = await AssetAudioCatalog().sourceFor(
      const AudioTrack('assets/audio/tick_clock.ogg'),
    );
    await _tick.load(source);
  }
  ```
  No `setState`/readiness flag is needed for the tick (unlike `_cueReady`), since the timer only starts after calibration begins, by which point the pre-buffer has had time to load; a not-yet-loaded `play()` is a no-op.

- [x] **Task 2: Start/stop the periodic tick from the calibration listener** (depends on Task 1)
  Files: `packages/bci_module/lib/src/BciPairing/Views/BciCalibrationSection.dart`
  The existing `ref.listen<BciPairingState>(bciPairingViewModelProvider, ...)` in `build()` already fires the completion cue. Extend that **same listener callback** (avoid adding a second `.select` listener — keep it consistent with the existing full-state listener) to drive the tick timer based on `next.calibration`:
  ```dart
  final inProgress =
      next.calibration != null && !next.calibration!.isComplete;
  if (inProgress && _tickTimer == null) {
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick.play();
    });
  } else if (!inProgress) {
    _tickTimer?.cancel();
    _tickTimer = null;
  }
  ```
  The `_tickTimer == null` guard prevents a duplicate timer when the listener fires repeatedly while calibration is already running. Setting `calibration` to `null` (failure/disconnect) or to a complete value both resolve `inProgress` to `false`, so the tick stops immediately in every terminal case.

- [x] **Task 3: Cancel timer and dispose the tick player** (depends on Task 1)
  Files: `packages/bci_module/lib/src/BciPairing/Views/BciCalibrationSection.dart`
  In the existing `dispose()`, cancel the timer and dispose the tick player before `super.dispose()`:
  ```dart
  @override
  void dispose() {
    _tickTimer?.cancel();
    _tick.dispose();
    _completionCue.dispose();
    super.dispose();
  }
  ```

## Notes
- `mind_audio` is already a dependency of `bci_module`; `AudioOneShot`, `AssetAudioCatalog`, and `AudioTrack` are already imported in this file — no pubspec or import changes required.
- Verify the root app `pubspec.yaml` exposes `assets/audio/` so `tick_clock.ogg` is bundled (the sibling `tick_heartbeat.ogg` confirms the directory is already declared).
- Manual check: start calibration with eyes closed — a tick should be audible each second; ticking stops the moment calibration completes (around when `calibration_complete.wav` fires) or the device disconnects; re-entering the screen and restarting plays the tick again from the first second.
