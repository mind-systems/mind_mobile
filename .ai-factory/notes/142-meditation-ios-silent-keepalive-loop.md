# Meditation iOS silent keep-alive loop

**Date:** 2026-06-22
**Source:** conversation context

## Key Findings

- Meditation plays **no audio**, so the iOS `audio` background mode (note 138) has nothing to keep active during a meditation — iOS still suspends the app ~1 min after lock. (Android is already covered by the foreground service, note 139.)
- Playing a **silent looping track** during an active meditation holds the iOS audio session open, so the process stays alive and the wall-clock timer (note 141) plus any biometric streaming keep running while the device is locked.

## Details

### Current state
- `packages/meditation_module/.../MeditationSessionViewModel.dart` — no audio anywhere in the package (verified).
- `packages/mind_audio` exposes `AudioLooper` (dual-player crossfader) and `AudioOneShot`; assets are loaded via `AssetAudioCatalog`.
- Note 138 configures the global iOS audio session (`playback`) + `UIBackgroundModes: [audio]`.

### Change
1. Add a short **digital-silence** loop asset (e.g. `assets/audio/silence.flac`, a few seconds) and declare it under `flutter: assets:` in `pubspec.yaml`.
2. Add a minimal `SilentKeepAlivePlayer` to `packages/mind_audio` (a single looping `just_audio` player, or reuse `AudioLooper` with one source) — `start()`/`stop()`.
3. Wire it into the meditation feature (a coordinator/observer keyed on `MeditationSessionStatus`): on `active` → `start()`, on `idle` → `stop()`. Guard with `Platform.isIOS` (Android relies on the FGS; a silent track there is unnecessary).
4. Keep it scoped to meditation; breath holds its own audio session via its real loop (note 140).

### Guards
- **iOS-only** (`Platform.isIOS`).
- True silence (silent asset and/or volume 0) so nothing is audible.
- Stop on `idle` to release the audio session (don't leave it pinned after the session ends).
- Depends on note 138 (session config) and complements note 141 (timer). Re-arm cleanly across repeated meditations.

### Verify
- On a physical iOS device: start meditation **while your own music plays**, lock the phone; after >1 min the elapsed time is correct, logs continue (no 1-minute suspension gap), and your music keeps playing untouched.

## Open Questions
- None. The silent loop inherits the global `mixWithOthers` session policy from note 138 — it never ducks the user's audio (the user may play their own music under the meditation).
