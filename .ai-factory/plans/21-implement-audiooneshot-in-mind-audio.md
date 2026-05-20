# Plan: Implement `AudioOneShot` in `mind_audio`

## Context
Extract the one-shot tick player mechanics (currently `_tickPlayer` + `_loadTickAsset` + `_onTick` in `BreathSoundCoordinator`) into a reusable `AudioOneShot` primitive inside the `mind_audio` package. This is a pure mechanics class — no domain knowledge, no guards, no streams — that owns a single `AudioPlayer` pre-buffered with one `AudioSource` so subsequent `play()` calls are seek-and-go.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Implement the primitive

- [x] **Task 1: Create `AudioOneShot` class**
  Files: `packages/mind_audio/lib/src/audio_one_shot.dart`
  Create a new file with a `dart:async` import (for `unawaited`) and a `package:just_audio/just_audio.dart` import. Define a non-abstract class `AudioOneShot` with:
  - A single private field `final AudioPlayer _player = AudioPlayer();` (created eagerly in the field initializer — no constructor body needed; default `const AudioOneShot()` is not possible because of the non-const field, so leave the default generative constructor implicit).
  - `Future<void> load(AudioSource source) async { await _player.setAudioSource(source); }` — pre-buffers the source so each subsequent `play()` only needs `seek + play`. This mirrors the current `_loadTickAsset` pattern in `BreathSoundCoordinator` (`packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart:219-223`) which calls `await player.setAsset(...)` once and then fires `seek(Duration.zero).then((_) => player.play())` per tick.
  - `void play() { unawaited(_player.seek(Duration.zero).then((_) => _player.play())); }` — fire-and-forget; matches the existing `_onTick()` body at `BreathSoundCoordinator.dart:235`.
  - `void stop() { unawaited(_player.stop()); }` — matches the current `unawaited(_tickPlayer?.stop())` pattern used in `suspend()` and `reset()` (`BreathSoundCoordinator.dart:126, 162`).
  - `void dispose() { unawaited(_player.dispose()); }` — matches the dispose pattern in `AudioLooper.dispose()` (`packages/mind_audio/lib/src/audio_looper.dart:102-103`).
  Add concise dartdoc on the class describing the pre-buffer + seek-and-go contract, and a one-liner on each public method (style matches `AudioLooper`).

- [x] **Task 2: Export `AudioOneShot` from package barrel** (depends on Task 1)
  Files: `packages/mind_audio/lib/mind_audio.dart`
  Append `export 'src/audio_one_shot.dart';` after the existing three exports (`audio_track.dart`, `audio_catalog.dart`, `audio_looper.dart`). Preserve alphabetical/logical grouping — placing it after `audio_looper` keeps the looper/one-shot pair adjacent.
