import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_track.dart';

/// Builds a `just_audio` [AudioSource] from an [AudioTrack].
abstract class AudioCatalog {
  Future<AudioSource> sourceFor(AudioTrack track);
}

/// [AudioCatalog] that resolves tracks from Flutter asset bundles.
///
/// For each [AudioTrack] it attempts to load a `<assetPath>.meta.json`
/// sidecar via [rootBundle]. If the sidecar contains `loop_end_ms`, the
/// asset is wrapped in a [ClippingAudioSource] to eliminate the OGG
/// encoder-delay click at loop boundaries. When no sidecar exists (or it
/// is malformed), a plain [AudioSource.asset] is returned.
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
