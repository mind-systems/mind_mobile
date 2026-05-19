# AudioCatalog + AssetAudioCatalog — Implementation Spec

**Date:** 2026-05-19
**Source:** Phase 13 roadmap planning

## Key Findings

- `AudioCatalog` is a single-method interface — only concern is building an `AudioSource` from an `AudioTrack`.
- `AssetAudioCatalog` reads a `.meta.json` sidecar from `rootBundle`; if `loop_end_ms` is present it wraps the source in `ClippingAudioSource` to eliminate OGG encoder-delay click.
- Format-agnostic: `.ogg`, `.wav`, `.mp3` all flow through the same code path. `ClippingAudioSource` is only applied when a sidecar exists.

## Details

### File

`packages/mind_audio/lib/src/audio_catalog.dart`

Export both classes from `packages/mind_audio/lib/mind_audio.dart`.

### AudioCatalog (abstract)

```dart
abstract class AudioCatalog {
  Future<AudioSource> sourceFor(AudioTrack track);
}
```

### AssetAudioCatalog (concrete)

```dart
class AssetAudioCatalog implements AudioCatalog {
  @override
  Future<AudioSource> sourceFor(AudioTrack track) async {
    try {
      final raw = await rootBundle.loadString('${track.assetPath}.meta.json');
      final meta = jsonDecode(raw) as Map<String, dynamic>;
      final loopEndMs = meta['loop_end_ms'];
      if (loopEndMs != null) {
        // ClippingAudioSource is required for all looping OGG files.
        // The Vorbis encoder adds ~1024 priming samples (encoder delay) that
        // inflate the decoded buffer past the true loop length, causing an
        // audible click at every loop boundary. loop_end_ms is read from
        // <name>.ogg.meta.json and represents the exact source WAV duration.
        return ClippingAudioSource(
          child: AudioSource.asset(track.assetPath),
          end: Duration(milliseconds: (loopEndMs as num).round()),
        );
      }
    } catch (_) {
      // No sidecar or malformed JSON — fall through to plain source.
    }
    return AudioSource.asset(track.assetPath);
  }
}
```

### Asset registration

Root `pubspec.yaml` already declares `- assets/audio/` as a directory glob, so the three `.meta.json` sidecars (`ohm_inhale.ogg.meta.json`, `ohm_exhale.ogg.meta.json`, `ohm_hold.ogg.meta.json`) are already registered. No change needed.
