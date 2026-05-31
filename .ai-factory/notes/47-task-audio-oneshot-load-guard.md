# Task Spec — Guard `AudioOneShot.play()` against an in-flight `load()`

**Date:** 2026-05-31
**Roadmap:** ROADMAP.md Phase 26
**Provenance:** note 42 Task 2 (note 35 Area A)

## Current state
`packages/mind_audio/lib/src/audio_one_shot.dart`: `load()` awaits `setAudioSource` while `play()` fires `seek(0).then(play)` with no guard. In `BreathSoundCoordinator._onStateChanged` a tick-source change (heart↔timer toggle, Phase 22) fires `_oneShot.load(src)` unawaited while `_onTick` may call `_oneShot.play()` concurrently — `setAudioSource` racing `seek`/`play` on the same player produces a glitched or no-op tick.

## Target
- Add `bool _loading = false;`.
- Set it `true` at the start of `load()` and `false` in a `finally` around `await _player.setAudioSource(source)`.
- In `play()`, `return` early when `_loading` (dropping a single tick during the brief buffer swap is acceptable).

## Guards
- No public API change, no caller change.

## Files
- `packages/mind_audio/lib/src/audio_one_shot.dart` (one file).
