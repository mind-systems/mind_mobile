import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_track.dart';

/// A one-shot audio player pre-buffered with a single [AudioTrack].
class AudioOneShot {
  final AudioPlayer _player = AudioPlayer();
  bool _loading = false;

  /// Loads [track] and plays it once silently to warm up ExoPlayer's read
  /// buffer and the OS page cache.
  ///
  /// The first audible play of a cold local asset underruns on Android
  /// (just_audio #941): ExoPlayer fills only the minimum AudioTrack buffer
  /// (~78 ms) before playback begins, then can't refill fast enough. After
  /// even a partial silent play the asset is in the OS page cache, so the
  /// next call to [play] delivers the full audio without underrun.
  Future<void> load(AudioTrack track) async {
    _loading = true;
    try {
      await _player.setAudioSource(AudioSource.asset(track.assetPath));
      await _player.setVolume(0);
      unawaited(_player.play());
      // Allow enough time for ExoPlayer to read the file into its buffer.
      await Future.delayed(const Duration(milliseconds: 200));
      await _player.stop();
      await _player.seek(Duration.zero);
      await _player.setVolume(1);
    } finally {
      _loading = false;
    }
  }

  /// Seeks to the start and plays. Fire-and-forget.
  void play() {
    if (_loading) return;
    unawaited(
      _player
          .seek(Duration.zero)
          .then((_) => _player.play())
          .catchError((Object e) {
        debugPrint('[AudioOneShot] play failed: $e  state=${_player.processingState}');
      }),
    );
  }

  /// Stops playback immediately. Fire-and-forget.
  void stop() {
    unawaited(_player.stop());
  }

  /// Disposes the underlying player. Fire-and-forget.
  void dispose() {
    unawaited(_player.dispose());
  }
}
