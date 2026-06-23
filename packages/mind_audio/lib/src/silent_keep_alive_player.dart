import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:mind_logger/mind_logger.dart';

/// Plays a silent looping asset to keep the iOS audio session alive.
///
/// On iOS the [audio] background mode requires an active audio session to
/// prevent app suspension after the screen locks. Playing a genuinely silent
/// looping track (volume = 0 + silent asset) holds the session open without
/// any audible output.
///
/// The player is asset-agnostic — the asset path is supplied via the
/// constructor so the package stays decoupled from app asset names.
class SilentKeepAlivePlayer {
  final String _assetPath;
  final AudioPlayer _player = AudioPlayer();
  bool _loaded = false;

  SilentKeepAlivePlayer({required String assetPath}) : _assetPath = assetPath;

  /// Starts silent looping playback.
  ///
  /// Lazily loads the source on the first call. Safe to call again after
  /// [stop] — seeks to zero and resumes playback for the next session.
  void start() {
    if (_loaded) {
      unawaited(
        _player
            .seek(Duration.zero)
            .then((_) => _player.play())
            .catchError((Object e) {
          logPrint('[SilentKeepAlivePlayer] play failed: $e');
        }),
      );
      return;
    }
    unawaited(_loadAndPlay());
  }

  Future<void> _loadAndPlay() async {
    try {
      await _player.setVolume(0);
      await _player.setAudioSource(AudioSource.asset(_assetPath));
      await _player.setLoopMode(LoopMode.one);
      _loaded = true;
      await _player.play();
    } catch (e) {
      logPrint('[SilentKeepAlivePlayer] load failed: $e');
    }
  }

  /// Stops playback so iOS can deactivate the audio session.
  void stop() {
    unawaited(_player.stop());
  }

  /// Disposes the underlying player. Fire-and-forget.
  void dispose() {
    unawaited(_player.dispose());
  }
}
