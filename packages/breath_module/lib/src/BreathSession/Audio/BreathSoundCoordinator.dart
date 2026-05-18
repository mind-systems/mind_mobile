import 'dart:async';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import '../../CommonModels/TickSource.dart';
import '../Models/BreathSessionState.dart';
import '../BreathSessionViewModel.dart';

class BreathSoundCoordinator {
  final BreathViewModel viewModel;

  AudioPlayer? _loopPlayer;
  AudioPlayer? _tickPlayer;
  StreamSubscription<void>? _tickSub;
  TickSource _currentTickSource = TickSource.timer;

  void Function()? _stateListener;
  BreathPhase? _currentPhase;
  BreathSessionStatus? _currentStatus;
  Timer? _fadeTimer;
  int _switchGen = 0;

  static const Map<BreathPhase, String> _phaseAssets = {
    BreathPhase.inhale: 'assets/audio/ohm_inhale.ogg',
    BreathPhase.exhale: 'assets/audio/ohm_exhale.ogg',
    BreathPhase.hold:   'assets/audio/ohm_hold.ogg',
    // rest → silence (no entry)
  };

  static const Map<TickSource, String> _tickAssets = {
    TickSource.timer:     'assets/audio/tick_clock.ogg',
    TickSource.heartbeat: 'assets/audio/tick_heartbeat.ogg',
  };

  BreathSoundCoordinator({required this.viewModel});

  void initialize(BreathSessionState initialState) {
    if (_loopPlayer != null) return;
    _loopPlayer = AudioPlayer();
    unawaited(_loopPlayer!.setLoopMode(LoopMode.one));

    _currentTickSource = initialState.tickSource;
    _tickPlayer = AudioPlayer();
    unawaited(_loadTickAsset(_currentTickSource));

    _tickSub = viewModel.tickStream.listen((_) => _onTick());
    _stateListener = viewModel.listen(_onStateChanged);
  }

  void reset() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    final player = _loopPlayer;
    if (player != null) {
      unawaited(player.stop());
      unawaited(player.setVolume(0.0));
    }
    final tickPlayer = _tickPlayer;
    if (tickPlayer != null) {
      unawaited(tickPlayer.stop());
    }
    _currentPhase = null;
    _currentStatus = null;
  }

  void dispose() {
    _tickSub?.cancel();
    _tickSub = null;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _stateListener?.call();
    _stateListener = null;
    final player = _loopPlayer;
    _loopPlayer = null;
    if (player != null) {
      unawaited(player.dispose());
    }
    final tickPlayer = _tickPlayer;
    _tickPlayer = null;
    if (tickPlayer != null) {
      unawaited(tickPlayer.dispose());
    }
  }

  void _onStateChanged(BreathSessionState state) {
    // 1. Load gate
    if (state.loadState != SessionLoadState.ready) return;

    // 2. Tick-source change (stable within a session; guard for correctness across restarts)
    if (state.tickSource != _currentTickSource) {
      _currentTickSource = state.tickSource;
      unawaited(_loadTickAsset(_currentTickSource));
    }

    // 3. Status changes
    if (state.status != _currentStatus) {
      _currentStatus = state.status;
      switch (state.status) {
        case BreathSessionStatus.pause:
          _fadeTo(0.0, const Duration(milliseconds: 200));
        case BreathSessionStatus.breath:
          if (_phaseAssets.containsKey(state.phase) && state.phase != _currentPhase) {
            _currentPhase = state.phase;
            unawaited(_switchToPhase(state.phase));
          } else {
            _fadeTo(1.0, const Duration(milliseconds: 200));
          }
        case BreathSessionStatus.complete:
        case BreathSessionStatus.rest:
          _fadeTo(0.0, const Duration(milliseconds: 500));
      }
      return;
    }

    // 4. Phase changes
    if (state.phase != _currentPhase) {
      _currentPhase = state.phase;
      if (_phaseAssets.containsKey(state.phase)) {
        unawaited(_switchToPhase(state.phase));
      } else {
        _fadeTo(0.0, const Duration(milliseconds: 500));
      }
      return;
    }

    // 5. End-of-phase fade-out trigger
    if (_currentStatus == BreathSessionStatus.breath &&
        _phaseAssets.containsKey(state.phase) &&
        state.remainingTicks > 0 &&
        state.remainingTicks <= 3) {
      final intervalMs = state.currentIntervalMs > 0 ? state.currentIntervalMs : 1000;
      _fadeTo(0.0, Duration(milliseconds: state.remainingTicks * intervalMs));
    }
  }

  Future<void> _loadTickAsset(TickSource source) async {
    final player = _tickPlayer;
    if (player == null) return;
    await player.setAsset(_tickAssets[source]!);
  }

  void _onTick() {
    final isInPause = _currentStatus == BreathSessionStatus.pause;
    final isRestPhase = _currentStatus == BreathSessionStatus.breath &&
        _currentPhase == BreathPhase.rest;
    if (!isInPause && !isRestPhase) return;
    final player = _tickPlayer;
    if (player == null) return;
    unawaited(player.seek(Duration.zero).then((_) => player.play()));
  }

  Future<void> _switchToPhase(BreathPhase phase) async {
    final gen = ++_switchGen;
    final asset = _phaseAssets[phase];
    if (asset == null) return;
    final player = _loopPlayer;
    if (player == null) return;
    await player.stop();
    await player.setAsset(asset);
    await player.setVolume(0.0);
    await player.play();
    // Bail out if a newer switch arrived, or if the session is no longer active.
    if (gen != _switchGen) return;
    if (_currentStatus != BreathSessionStatus.breath) return;
    _fadeTo(1.0, const Duration(seconds: 2));
  }

  void _fadeTo(double target, Duration duration) {
    _fadeTimer?.cancel();
    final player = _loopPlayer;
    if (player == null) return;
    final startVolume = player.volume;
    final steps = max(1, duration.inMilliseconds ~/ 16);
    var tick = 0;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      tick++;
      final t = (tick / steps).clamp(0.0, 1.0);
      final v = startVolume + (target - startVolume) * t;
      unawaited(player.setVolume(v));
      if (tick >= steps) {
        timer.cancel();
        _fadeTimer = null;
      }
    });
  }
}
