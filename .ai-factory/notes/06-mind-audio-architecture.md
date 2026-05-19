# mind_audio — Architecture Note

## Why

`BreathSoundCoordinator` currently owns too much: asset paths, loop metadata, crossfade mechanics, one-shot playback, AND domain translation (phase → index, status → fade). Splitting audio primitives into a standalone package removes the domain coupling and makes the same mechanics reusable for meditation instructions, ambient audio, and anything else.

## Package: `packages/mind_audio`

Zero domain knowledge. No imports from `breath_module` or `lib/`.

### `AudioTrack`

Value object. Carries everything needed to play one audio asset.

```dart
class AudioTrack {
  final String assetPath;
  final Duration? loopEnd; // null = no clipping (one-shots)
}
```

### `AudioCatalog`

Loads tracks from Flutter asset bundle. Reads `.meta.json` sidecars and wraps in `ClippingAudioSource` where `loopEnd` is set.

```dart
abstract class AudioCatalog {
  Future<AudioSource> sourceFor(AudioTrack track);
}
```

Default implementation (`AssetAudioCatalog`) reads `<path>.meta.json`, extracts `loop_end_ms`, returns `ClippingAudioSource(child: AudioSource.asset(...), end: Duration(milliseconds: loopEndMs))`. If no sidecar → plain `AudioSource.asset`.

### `AudioLooper`

Ping-pong crossfade player. Owns two `AudioPlayer` instances loaded with the same playlist. No concept of phases or breath.

```dart
class AudioLooper {
  Future<void> initialize(List<AudioSource> sources);
  void crossfadeTo(int index, Duration fadeDuration);
  void fadeOut(Duration duration);
  void fadeIn(Duration duration);  // resumes active player
  void stop();
  void dispose();
}
```

Internally: the same ping-pong + gen-check + `_fadePlayer` logic currently in `BreathSoundCoordinator`.

### `AudioOneShot`

Single player for triggered sounds. Seek-and-play pattern.

```dart
class AudioOneShot {
  Future<void> load(AudioSource source);
  void play();
  void stop();
  void dispose();
}
```

Internally: the same `seek(Duration.zero).then((_) => play())` pattern currently in `BreathSoundCoordinator` for ticks.

## How BreathSoundCoordinator changes

Receives `AudioLooper` and `AudioOneShot` via constructor (or factory). Keeps only domain logic:

- `BreathPhase → playlist index` mapping
- `BreathSessionStatus → looper.fadeOut / looper.crossfadeTo`
- `_computeFadeDuration` (phase length → crossfade duration)
- Tick guard (`allowTick` conditions)
- State listener wiring

No more `AudioPlayer`, `ClippingAudioSource`, `LoopMode`, `setAudioSources` in the coordinator.

## How meditation will use it

`MeditationSoundCoordinator` (future, in `packages/meditation_module` or `lib/MeditationModule/`):
- `AudioOneShot` for voice instruction playback triggered at specific session moments
- Optionally `AudioLooper` for ambient background audio
- Own `AudioCatalog` with meditation tracks and their sidecars

## Open questions

- Does `AudioLooper.initialize()` load metadata itself (receives `List<AudioTrack>`) or receive pre-built `List<AudioSource>` from the caller?
  - Option A: Looper receives `List<AudioSource>` — caller is responsible for catalog
  - Option B: Looper receives `List<AudioTrack>` + `AudioCatalog` — loads internally
  - Lean toward A: keeps `AudioLooper` simpler, catalog stays in one place
- Package name: `mind_audio` or `audio_primitives` or just extend `mind_ui`?
  - Separate package preferred — `mind_ui` is UI-only, audio has no UI
- Where does `AudioCatalog` live when wiring breath module? In `lib/BreathModule/BreathModule.dart` (assembly point).
