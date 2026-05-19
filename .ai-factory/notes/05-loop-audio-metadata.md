# Loop Audio — OGG Encoder Delay & Metadata Sidecar Architecture

**Date:** 2026-05-19
**Source:** conversation context

## Key Findings

- OGG Vorbis encoder adds ~1024 priming samples (encoder delay) at the start of the stream; the browser / `just_audio` may not strip them correctly, causing an audible click at every loop boundary.
- The fix is to tell the player the *exact* duration of the original source — `loopEnd` in Web Audio API, `ClippingAudioSource(end: ...)` in `just_audio`. This truncates the decoded buffer to the true loop length, throwing away the encoder padding.
- Every loop audio file must travel with a sidecar `.meta.json` that records the authoritative `loop_end_ms`. Code that plays looping audio **must** read this file and apply the value — this is not optional.
- One-shot sounds (tick_clock, tick_heartbeat, etc.) are not affected and do not need metadata.

## Details

### Why the click happens

Vorbis encodes audio in blocks. The first block contains "priming" samples (encoder delay, typically 1024 samples at 44 100 Hz ≈ 23 ms) that are technically part of the bitstream but not part of the original audio. Some decoders silently strip them; others leave them, producing a buffer that is slightly longer than the source. When the player loops at `buffer.duration` instead of the true source duration, those extra samples play and then cut back to zero — click.

### The fix: ClippingAudioSource

In `BreathSoundCoordinator.dart`, all looping OGG sources are wrapped:

```dart
ClippingAudioSource(
  child: AudioSource.asset(_phaseAssets[p]!),
  end: Duration(milliseconds: meta.loopEndMs.round()),
)
```

`loop_end_ms` is read from the sidecar file at startup. For the current baked files it is exactly `4000.0` ms, but the architecture must not hard-code this — future samples will have different lengths.

### Sidecar file convention

For every loop OGG at `assets/audio/<name>.ogg`, there is a companion:

```
assets/audio/<name>.ogg.meta.json
```

Schema (intentionally minimal — extend if needed):

```json
{
  "loop_end_ms": 4000.0
}
```

`loop_end_ms` — the duration of the *original WAV source* in milliseconds, measured before OGG encoding. This is the value to pass to `ClippingAudioSource(end: ...)`.

### How to produce metadata when adding a new loop sample

1. Measure the source WAV: `python3 -c "import soundfile as sf; d,sr=sf.read('file.wav'); print(len(d)/sr*1000)"` (or equivalent server-side).
2. Write `<name>.ogg.meta.json` with the result.
3. Encode to OGG as usual (`ffmpeg -c:a libvorbis -q:a 6`).
4. Drop both files into `assets/audio/`.
5. Register both in `pubspec.yaml` assets.

### One-shot sounds — no metadata needed

`tick_clock.ogg` and `tick_heartbeat.ogg` are triggered once per event and seeked back to zero before each play. They do not use `LoopMode.one` and are not wrapped in `ClippingAudioSource`. Encoder delay on one-shots is inaudible.

### Code comment requirement

Any code that constructs an `AudioSource` for a looping OGG **must** include a comment explaining:
- why `ClippingAudioSource` is used (encoder delay)
- where `loop_end_ms` comes from (the `.meta.json` sidecar)

Example:

```dart
// ClippingAudioSource is required for all looping OGG files.
// The Vorbis encoder adds ~1024 priming samples (encoder delay) that
// inflate the decoded buffer past the true loop length, causing an
// audible click at every loop boundary. loop_end_ms is read from
// <name>.ogg.meta.json and represents the exact source WAV duration.
ClippingAudioSource(
  child: AudioSource.asset(asset),
  end: Duration(milliseconds: meta.loopEndMs.round()),
)
```

## Open Questions

- Where does metadata loading live? (a dedicated `AudioMetaRepository` or inline in `BreathSoundCoordinator`) — to be decided when implementing the loader.
- Server-side pipeline for user-uploaded samples: WAV → measure duration → encode OGG → write `.meta.json` → upload both. Storage location TBD.
