import 'package:flutter/foundation.dart';

/// Immutable descriptor of an audio asset used for playback.
///
/// [assetPath] is the Flutter asset path used to load the audio source
/// (e.g. `assets/audio/ohm_inhale.flac`).
@immutable
class AudioTrack {
  final String assetPath;

  const AudioTrack(this.assetPath);
}
