import 'package:flutter/foundation.dart';

/// Immutable descriptor of an audio asset used for playback.
///
/// [assetPath] is the Flutter asset path (e.g. `assets/audio/rain.ogg`).
/// [loopEnd] is the authoritative source-WAV duration to pass to
/// `ClippingAudioSource(end:)` when the asset is an OGG loop — clipping
/// removes the encoder-delay click that occurs at the loop boundary.
/// A `null` value means no clipping is applied (one-shots and WAV loops).
@immutable
class AudioTrack {
  final String assetPath;

  /// The end timestamp of the clean audio content in the source WAV.
  ///
  /// Pass this to `ClippingAudioSource(end:)` for OGG loop files to strip
  /// the encoder-delay silence and prevent a click at the loop point.
  /// `null` means no clipping — suitable for one-shots and native WAV loops.
  final Duration? loopEnd;

  const AudioTrack(this.assetPath, {this.loopEnd});
}
