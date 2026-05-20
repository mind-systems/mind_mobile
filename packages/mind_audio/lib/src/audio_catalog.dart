import 'package:just_audio/just_audio.dart';

import 'audio_track.dart';

/// Builds a `just_audio` [AudioSource] from an [AudioTrack].
abstract class AudioCatalog {
  Future<AudioSource> sourceFor(AudioTrack track);
}

/// [AudioCatalog] that resolves tracks from Flutter asset bundles.
///
/// Returns a plain [AudioSource.asset] for the track's asset path.
class AssetAudioCatalog implements AudioCatalog {
  @override
  Future<AudioSource> sourceFor(AudioTrack track) async {
    return AudioSource.asset(track.assetPath);
  }
}
