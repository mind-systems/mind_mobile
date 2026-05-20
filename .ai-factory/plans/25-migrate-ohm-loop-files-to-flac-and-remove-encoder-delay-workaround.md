# Plan: Migrate ohm loop files to FLAC and remove encoder-delay workaround

## Context
Switch the breathing-phase loop assets from OGG/Opus to FLAC so `LoopMode.one` loops at the exact sample boundary (no encoder priming, no click), and remove the now-obsolete `ClippingAudioSource` + `.meta.json` sidecar workaround from the `mind_audio` package. Note: the live code currently references `ohm_*.opus` (not `.wav` as the milestone wording suggests); the swap is `.opus` → `.flac`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Update loop asset references

- [x] **Task 1: Point BreathSoundCoordinator at the FLAC loop files**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  In the `_phaseAssets` map (around line 31), change the three values from `assets/audio/ohm_inhale.opus` / `ohm_exhale.opus` / `ohm_hold.opus` to `assets/audio/ohm_inhale.flac` / `ohm_exhale.flac` / `ohm_hold.flac`. Keep map keys (`BreathPhase.inhale/exhale/hold`) and the surrounding comment intact. Do not touch `_tickAssets` — `tick_clock.ogg` and `tick_heartbeat.ogg` are one-shots and remain unchanged. No other edits in this file.

### Phase 2: Strip the encoder-delay workaround from `mind_audio`

- [x] **Task 2: Simplify `AssetAudioCatalog.sourceFor()`** (depends on Task 1)
  Files: `packages/mind_audio/lib/src/audio_catalog.dart`
  - Remove the top-of-file imports `import 'dart:convert';` and `import 'package:flutter/services.dart';` (the `just_audio` import stays).
  - Replace the entire body of `AssetAudioCatalog.sourceFor()` with a single line: `return AudioSource.asset(track.assetPath);`. Drop the try/catch, the `rootBundle.loadString('${track.assetPath}.meta.json')` read, the `jsonDecode`, the `loopEndMs` branch, and the `ClippingAudioSource` wrapping.
  - Update the class-level dartdoc on `AssetAudioCatalog` so it no longer mentions `.meta.json` sidecars, `loop_end_ms`, `ClippingAudioSource`, or the OGG encoder-delay click — describe it simply as an `AudioCatalog` that returns a plain `AudioSource.asset(...)` for the track's asset path. Leave the `AudioCatalog` abstract class and its dartdoc unchanged.

- [x] **Task 3: Reduce `AudioTrack` to a single-field value object** (depends on Task 2)
  Files: `packages/mind_audio/lib/src/audio_track.dart`
  - Remove the `final Duration? loopEnd;` field and its dartdoc.
  - Change the constructor to `const AudioTrack(this.assetPath);` (no named parameters).
  - Rewrite the class-level dartdoc so it only describes `assetPath` (e.g. the Flutter asset path used for playback) and drops every reference to `loopEnd`, OGG, encoder delay, `ClippingAudioSource`, and WAV loops.
  - Keep the `@immutable` annotation and the `package:flutter/foundation.dart` import that provides it.
  - All existing call sites already use the positional form `AudioTrack(path)` (verified in `BreathSoundCoordinator`), so no caller updates are required.

## Notes for the implementer
- The FLAC files `ohm_inhale.flac`, `ohm_exhale.flac`, `ohm_hold.flac` are already present in `assets/audio/`; the old OGG/Opus files and any `.meta.json` sidecars have already been removed from the repo, so no asset bundling or `pubspec.yaml` change is needed (the directory glob covers them).
- Three tasks total → no commit checkpoints; a single commit at the end is fine.
