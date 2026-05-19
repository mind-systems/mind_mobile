# Plan: Implement `AudioCatalog` and `AssetAudioCatalog` in `mind_audio`

## Context
Adds the catalog abstraction to `packages/mind_audio` that builds a `just_audio` `AudioSource` from an `AudioTrack`, automatically wrapping in `ClippingAudioSource` when a `.meta.json` sidecar provides `loop_end_ms` — eliminating the OGG encoder-delay click at loop boundaries. Format-agnostic; no pubspec or asset changes required.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Implement the catalog

- [x] **Task 1: Create `audio_catalog.dart` with `AudioCatalog` and `AssetAudioCatalog`**
  Files: `packages/mind_audio/lib/src/audio_catalog.dart`
  Create a new file in the `mind_audio` package containing two classes:

  1. Abstract class `AudioCatalog` with a single method:
     ```dart
     abstract class AudioCatalog {
       Future<AudioSource> sourceFor(AudioTrack track);
     }
     ```

  2. Concrete class `AssetAudioCatalog implements AudioCatalog` whose `sourceFor` implementation:
     - Attempts `rootBundle.loadString('${track.assetPath}.meta.json')`.
     - Parses the JSON; if `meta['loop_end_ms']` is non-null, returns
       `ClippingAudioSource(child: AudioSource.asset(track.assetPath), end: Duration(milliseconds: (loopEndMs as num).round()))`.
     - On any exception (missing sidecar, malformed JSON) or when `loop_end_ms` is absent, falls back to plain `AudioSource.asset(track.assetPath)`.

  Required imports: `dart:convert` (for `jsonDecode`), `package:flutter/services.dart` (for `rootBundle`), `package:just_audio/just_audio.dart` (for `AudioSource` and `ClippingAudioSource`), and the local `audio_track.dart` (for `AudioTrack`).

  Inside the `if (loopEndMs != null)` branch, include the required explanatory comment from `.ai-factory/notes/08-audio-catalog.md` verbatim:
  ```
  // ClippingAudioSource is required for all looping OGG files.
  // The Vorbis encoder adds ~1024 priming samples (encoder delay) that
  // inflate the decoded buffer past the true loop length, causing an
  // audible click at every loop boundary. loop_end_ms is read from
  // <name>.ogg.meta.json and represents the exact source WAV duration.
  ```

  The `catch (_)` block should carry the comment: `// No sidecar or malformed JSON — fall through to plain source.`

  Match the formatting/style of the existing `packages/mind_audio/lib/src/audio_track.dart` (no trailing commas in single-line constructors, dartdoc on public API).

- [x] **Task 2: Export the new file from the package barrel** (depends on Task 1)
  Files: `packages/mind_audio/lib/mind_audio.dart`
  Add `export 'src/audio_catalog.dart';` below the existing `export 'src/audio_track.dart';` line so both `AudioCatalog` and `AssetAudioCatalog` are visible via `import 'package:mind_audio/mind_audio.dart';`.

- [x] **Task 3: Verify the package compiles** (depends on Task 2)
  Files: (none — verification only)
  From `packages/mind_audio/`, run `/usr/local/bin/flutter pub get` followed by `/usr/local/bin/flutter analyze` to confirm there are no analyzer errors. No code changes — task ends green.
