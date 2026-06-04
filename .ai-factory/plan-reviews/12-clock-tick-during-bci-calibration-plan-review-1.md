# Plan Review: Clock tick during BCI calibration

**Plan:** `.ai-factory/plans/12-clock-tick-during-bci-calibration.md`
**Files Reviewed:** 1 target file + 4 supporting (mind_audio API, state/DTO models, pubspec, existing usage)
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** ✅ PASS. The change stays entirely inside the presentation package (`packages/bci_module/`), uses `mind_audio` (already a package dependency), and introduces no domain-model leak across the module boundary. Consistent with the layered/module rules in CLAUDE.md.
- **Rules (`RULES.md`):** ✅ PASS. No convention violations detected. Uses `dart:async` (`Timer`, `unawaited`) already imported in the file; no new imports or pubspec edits.
- **Roadmap (`ROADMAP.md`):** ✅ PASS. Properly linked — this is the open item on line 41 ("Clock tick during BCI calibration"), with spec note `.ai-factory/notes/79-bci-calibration-tick-sound.md`.

## Verification Against Codebase

Every assumption in the plan was checked against the actual code and holds:

- **API usage is correct.** `AudioOneShot.load()/play()/dispose()`, `AssetAudioCatalog().sourceFor()`, and `AudioTrack(...)` exist with the exact signatures the plan uses (`packages/mind_audio/lib/src/`). The plan mirrors the existing `_loadCue()` pattern precisely.
- **Asset path is correct and proven.** `assets/audio/tick_clock.ogg` exists, is declared in the root `pubspec.yaml` (line 115: `- assets/audio/`), and is **already played in production** by `BreathSoundCoordinator` (`TickSource.timer: 'assets/audio/tick_clock.ogg'`) via the identical `AssetAudioCatalog().sourceFor(AudioTrack(...))` + `AudioOneShot` mechanism. This also resolves any doubt about `.ogg` decoding on the target platforms and confirms a root-app asset path (no `packages/...` prefix) resolves correctly from inside a package widget.
- **State/terminal logic is correct.** `BciPairingState.calibration` is nullable; `BciCalibrationProgressDTO.isComplete` exists. `inProgress = calibration != null && !isComplete` correctly covers all three terminal cases (complete → `isComplete==true`; failure/disconnect → `calibration==null`).
- **Single-listener decision is sound.** Extending the existing full-state `ref.listen<BciPairingState>` callback (rather than adding a `.select` listener) is consistent with the current file, and the `_tickTimer == null` guard correctly prevents duplicate timers across repeated in-progress emissions.
- **Lifecycle is complete.** `dispose()` cancels the timer and disposes the player before `super.dispose()` — matches the existing `_completionCue` disposal.

## Critical Issues

None.

## Minor Notes (non-blocking)

- **WARN — "not-yet-loaded `play()` is a no-op" is slightly imprecise** (Task 1, last paragraph). Looking at `AudioOneShot.play()`, it only short-circuits while `_loading == true`. There is a brief window in `initState` *before* `load()` is awaited where `_loading` is still `false` and no source is set — a `play()` there would `seek`/`play` on an empty player. This is **practically irrelevant**: the timer only starts after calibration begins (seconds later), well after the pre-buffer completes, exactly as the plan reasons. No action required; flagging only so the rationale isn't mistaken for a hard guarantee.
- **INFO — listener doesn't fire for the current value.** `ref.listen` only fires on subsequent changes, so entering the screen mid-calibration would not start the tick until the next progress emission. This matches the existing completion-cue behavior and is acceptable for this feature.

## Positive Notes

- Plan explicitly overrides the spec note's raw `AudioSource.asset(...)` snippet in favor of the file's existing `AssetAudioCatalog` pattern — a deliberate, well-justified consistency choice.
- Correctly identifies that no `setState`/readiness flag is needed for the tick (unlike `_cueReady`), with sound reasoning.
- Task dependencies (Task 2 and 3 depend on Task 1) and the scope ("one file") are accurate.
- Terminal-case analysis (completion vs. null) is explicit and correct.

PLAN_REVIEW_PASS
