# Plan: Define `AudioTrack` value object in `mind_audio`

## Context
Introduce the foundational `AudioTrack` value object inside the `mind_audio` package — an immutable descriptor of an audio asset (path + optional source-WAV loop end) that later milestones will use to drive `just_audio` playback (including `ClippingAudioSource` to eliminate encoder-delay clicks on OGG loops).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Implementation

- [x] **Task 1: Create `AudioTrack` value object**
  Files: `packages/mind_audio/lib/src/audio_track.dart`
  Create the file with an immutable `AudioTrack` class:
  - Add `import 'package:flutter/foundation.dart';` for the `@immutable` annotation.
  - Annotate the class with `@immutable`.
  - Fields: `final String assetPath;` and `final Duration? loopEnd;`.
  - Constructor: `const AudioTrack(this.assetPath, {this.loopEnd});`.
  - Add a brief doc comment on the class and on `loopEnd` clarifying that `loopEnd == null` means no clipping (one-shots and WAV loops), while a non-null value is the authoritative source-WAV duration to pass to `ClippingAudioSource(end:)` — used for OGG loop files to remove encoder-delay click.
  - No other members (no `==`, `hashCode`, `copyWith`, etc.) — keep strictly to the milestone spec.

- [x] **Task 2: Replace the generated stub in `mind_audio.dart` with the export** (depends on Task 1)
  Files: `packages/mind_audio/lib/mind_audio.dart`
  Replace the entire current stub contents (the single comment line) with a library export:
  - `library mind_audio;` (optional, idiomatic) followed by `export 'src/audio_track.dart';`.
  - Ensure no other code or comments remain that reference "implementations land in later milestones".
  - Do not add any other exports — only `audio_track.dart`.

## Out of scope
- No changes to `pubspec.yaml`, tests, or any file outside the two listed above.
- No `==`/`hashCode`/`toString`/`copyWith` overrides on `AudioTrack`.
- No consumers of `AudioTrack` are wired up in this milestone.
