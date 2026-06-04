# Code Review: Clock tick during BCI calibration

**Plan:** `.ai-factory/plans/12-clock-tick-during-bci-calibration.md`
**Changed file (code):** `packages/bci_module/lib/src/BciPairing/Views/BciCalibrationSection.dart`
**Risk Level:** 🟢 Low

## Scope

`git status` / `git diff HEAD` show one code file changed plus plan/review artifacts (`.json`, `.md`). Only the Dart file affects runtime; reviewed in full alongside `mind_audio/AudioOneShot`, `BciPairingState`, root `pubspec.yaml`, and the existing `BreathSoundCoordinator` usage.

## Correctness Verification

Every assumption was checked against the actual code and holds:

- **Asset path resolves correctly.** `assets/audio/tick_clock.ogg` exists, is declared in the root `pubspec.yaml` (line 115: `- assets/audio/`), and the **identical** path is already played in production by `BreathSoundCoordinator` (`packages/breath_module/.../BreathSoundCoordinator.dart:43`) through the same `AssetAudioCatalog().sourceFor(AudioTrack(...))` + `AudioOneShot` mechanism. A root-app asset (no `packages/...` prefix) resolves from inside a package because `AudioSource.asset` reads `rootBundle`, which is owned by the host app. `.ogg` decoding on target platforms is likewise proven by that existing usage.
- **API signatures match.** `AudioOneShot.load(AudioSource)` / `play()` / `dispose()` exist with the exact shapes used. `AssetAudioCatalog().sourceFor(AudioTrack(path))` and the `mind_audio` import are already present in the file — no new imports or pubspec edits.
- **Terminal logic is correct.** `BciPairingState.calibration` is nullable; `BciCalibrationProgressDTO.isComplete` exists. `inProgress = calibration != null && !calibration!.isComplete` correctly covers all three stop cases: completion (`isComplete == true`), failure, and disconnect (both → `calibration == null`). The tick is cancelled in the same listener invocation that fires the completion cue.
- **No duplicate timers.** The `_tickTimer == null` guard prevents stacking a second `Timer.periodic` across repeated in-progress emissions (stage 0→4 progress updates).
- **Lifecycle is complete.** `dispose()` cancels `_tickTimer` and disposes `_tick` before `super.dispose()`. The cancelled timer guarantees no `_tick.play()` fires after disposal.
- **No `mounted`/`setState` needed for the tick.** Unlike `_loadCue` (which calls `setState` for `_cueReady`), `_loadTick` only loads — correctly omits the guard.

## Critical Issues

None.

## Minor Notes (non-blocking)

- **INFO — `play()` mid-load short-circuits, but the window is irrelevant.** `AudioOneShot.play()` no-ops only while `_loading == true`. There is a sub-millisecond window before `load()` sets `_loading` where a `play()` would seek an empty player — but the timer only starts seconds later when calibration begins, so this can never trigger. No action.
- **INFO — listener does not fire for the current value.** `ref.listen` fires only on subsequent changes, so re-entering the screen *mid-calibration* would not (re)start the tick until the next progress emission. This matches the existing completion-cue behavior and is acceptable for the feature.
- **INFO — pre-existing latent pattern, not a regression.** If the widget is disposed while `_loadTick()`/`_loadCue()` is still awaiting `setAudioSource`, the unawaited load would continue against a disposed player. This is identical to the pre-existing `_completionCue` handling, occurs only on near-instant screen exit, and the implementation deliberately mirrors the established pattern. Not introduced by this change.

## Positive Notes

- Cleanly mirrors the existing `_loadCue`/`_completionCue` structure (load helper, init, dispose) — consistent and easy to follow.
- Tick start/stop folded into the existing single `ref.listen<BciPairingState>` callback rather than adding a second `.select` listener, exactly as planned.
- Disposal ordering and timer cancellation are correct, leaving no dangling timer or player.

REVIEW_PASS
