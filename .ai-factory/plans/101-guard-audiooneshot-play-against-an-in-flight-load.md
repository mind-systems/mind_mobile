# Plan: Guard `AudioOneShot.play()` against an in-flight `load()`

## Context
Prevent a glitched/no-op tick when a tick-source toggle (heart↔timer) fires an unawaited `load()` while `play()` runs concurrently, by no-opping `play()` during the brief `setAudioSource` buffer swap.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Add load guard

- [x] **Task 1: Guard `play()` while `load()` is in flight**
  Files: `packages/mind_audio/lib/src/audio_one_shot.dart`
  Add a private `bool _loading = false;` field to `AudioOneShot`. In `load()`, set `_loading = true` before `await _player.setAudioSource(source)` and reset it to `false` in a `finally` block wrapping the await, so the flag clears even if `setAudioSource` throws. In `play()`, add an early `return` when `_loading` is `true` (before the existing `unawaited(_player.seek(...)...)` call) — dropping a single tick during the buffer swap is acceptable. Do not change the public API, method signatures, or any caller (e.g. `BreathSoundCoordinator`).
