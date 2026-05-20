import 'dart:async';
import 'package:just_audio/just_audio.dart';

/// A one-shot audio player pre-buffered with a single [AudioSource].
///
/// Call [load] once to buffer the source; subsequent [play] calls are
/// seek-and-go with no async overhead on the hot path.
class AudioOneShot {
  final AudioPlayer _player = AudioPlayer();

  /// Buffers [source] so that each subsequent [play] only needs seek + play.
  Future<void> load(AudioSource source) async {
    await _player.setAudioSource(source);
  }

  /// Seeks to the start of the buffered source and plays it. Fire-and-forget.
  void play() {
    unawaited(_player.seek(Duration.zero).then((_) => _player.play()));
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
