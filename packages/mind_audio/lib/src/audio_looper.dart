import 'dart:async';
import 'dart:math';
import 'package:just_audio/just_audio.dart';

/// Ping-pong crossfade player: two [AudioPlayer] instances swap roles on each
/// [crossfadeTo] call so one track fades out while the next fades in.
class AudioLooper {
  AudioPlayer? _playerA;
  AudioPlayer? _playerB;
  AudioPlayer? _activePlayer;
  AudioPlayer? _inactivePlayer;
  Timer? _fadeTimerA;
  Timer? _fadeTimerB;
  int _switchGen = 0;
  Future<void>? _loadFuture;

  /// Creates both players, preloads [sources] on each, and marks player A as
  /// the initial active player. Returns immediately — the load runs in the
  /// background and [crossfadeTo] awaits it internally before seeking.
  Future<void> initialize(List<AudioSource> sources) async {
    _playerA = AudioPlayer();
    _playerB = AudioPlayer();
    unawaited(_playerA!.setLoopMode(LoopMode.one));
    unawaited(_playerA!.setVolume(0.0));
    unawaited(_playerB!.setLoopMode(LoopMode.one));
    unawaited(_playerB!.setVolume(0.0));
    _activePlayer = _playerA;
    _inactivePlayer = _playerB;
    _loadFuture = Future.wait([
      _playerA!.setAudioSources(sources, preload: true),
      _playerB!.setAudioSources(sources, preload: true),
    ]);
    unawaited(_loadFuture!);
  }

  /// Crossfades from the currently active player to [index] in the playlist
  /// over [fadeDuration]. The outgoing player begins fading immediately
  /// (before any async work) to eliminate late-start artifacts.
  void crossfadeTo(int index, Duration fadeDuration) {
    final gen = ++_switchGen;
    final active = _activePlayer;
    final inactive = _inactivePlayer;
    if (active == null || inactive == null) return;

    // Start fading out the outgoing player immediately — before any await.
    _fadePlayer(active, 0.0, fadeDuration);

    unawaited(() async {
      if (_loadFuture != null) await _loadFuture;
      if (gen != _switchGen) return;

      _cancelFadeFor(inactive);
      await inactive.setVolume(0.0);
      await inactive.seek(Duration.zero, index: index);
      unawaited(inactive.play()); // never await play() — see Phase 12 bug history

      _activePlayer = inactive;
      _inactivePlayer = active;

      if (gen != _switchGen) return;
      _fadePlayer(_activePlayer!, 1.0, fadeDuration);
    }());
  }

  /// Fades the active player to silence over [duration].
  void fadeOut(Duration duration) => _fadePlayer(_activePlayer!, 0.0, duration);

  /// Fades the active player to full volume over [duration].
  void fadeIn(Duration duration) => _fadePlayer(_activePlayer!, 1.0, duration);

  /// Stops both players, resets volumes to zero, and resets the active/inactive
  /// assignment to its initial state (A active, B inactive).
  void stop() {
    _fadeTimerA?.cancel();
    _fadeTimerA = null;
    _fadeTimerB?.cancel();
    _fadeTimerB = null;
    for (final p in [_playerA, _playerB]) {
      if (p != null) {
        unawaited(p.stop());
        unawaited(p.setVolume(0.0));
      }
    }
    _activePlayer = _playerA;
    _inactivePlayer = _playerB;
  }

  /// Cancels fade timers and disposes both players. All fields are nulled
  /// before disposal to prevent callbacks from racing the teardown.
  void dispose() {
    _fadeTimerA?.cancel();
    _fadeTimerA = null;
    _fadeTimerB?.cancel();
    _fadeTimerB = null;
    final playerA = _playerA;
    final playerB = _playerB;
    _playerA = null;
    _playerB = null;
    _activePlayer = null;
    _inactivePlayer = null;
    _loadFuture = null;
    if (playerA != null) unawaited(playerA.dispose());
    if (playerB != null) unawaited(playerB.dispose());
  }

  void _cancelFadeFor(AudioPlayer player) {
    if (player == _playerA) {
      _fadeTimerA?.cancel();
      _fadeTimerA = null;
    } else {
      _fadeTimerB?.cancel();
      _fadeTimerB = null;
    }
  }

  void _fadePlayer(AudioPlayer player, double target, Duration duration) {
    _cancelFadeFor(player);
    final startVolume = player.volume;
    final steps = max(1, duration.inMilliseconds ~/ 16);
    var tick = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      tick++;
      final progress = (tick / steps).clamp(0.0, 1.0);
      final v = startVolume + (target - startVolume) * progress;
      unawaited(player.setVolume(v));
      if (tick >= steps) {
        t.cancel();
        if (player == _playerA) {
          _fadeTimerA = null;
        } else {
          _fadeTimerB = null;
        }
      }
    });
    if (player == _playerA) {
      _fadeTimerA = timer;
    } else {
      _fadeTimerB = timer;
    }
  }
}
