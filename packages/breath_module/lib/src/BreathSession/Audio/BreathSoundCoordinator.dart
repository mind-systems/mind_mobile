import 'dart:async';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import '../Models/BreathSessionState.dart';
import '../BreathSessionViewModel.dart';

class BreathSoundCoordinator {
  final BreathViewModel viewModel;

  AudioPlayer? _player;
  void Function()? _stateListener;
  BreathPhase? _currentPhase;
  BreathSessionStatus? _currentStatus;
  Timer? _fadeTimer;
  int _switchGen = 0;

  static const Map<BreathPhase, String> _phaseAssets = {
    BreathPhase.inhale: 'assets/audio/ohm_inhale.wav',
    BreathPhase.exhale: 'assets/audio/ohm_exhale.wav',
    BreathPhase.hold:   'assets/audio/ohm_hold.wav',
    // rest → silence (no entry)
  };

  BreathSoundCoordinator({required this.viewModel});

  void initialize(BreathSessionState initialState) {
    if (_player != null) return;
    _player = AudioPlayer();
    unawaited(_player!.setLoopMode(LoopMode.one));
    _stateListener = viewModel.listen(_onStateChanged);
  }

  void reset() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    final player = _player;
    if (player != null) {
      unawaited(player.stop());
      unawaited(player.setVolume(0.0));
    }
    _currentPhase = null;
    _currentStatus = null;
  }

  void dispose() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _stateListener?.call();
    _stateListener = null;
    final player = _player;
    _player = null;
    if (player != null) {
      unawaited(player.dispose());
    }
  }

  void _onStateChanged(BreathSessionState state) {
    // 1. Load gate
    if (state.loadState != SessionLoadState.ready) return;

    // 2. Status changes
    if (state.status != _currentStatus) {
      _currentStatus = state.status;
      switch (state.status) {
        case BreathSessionStatus.pause:
          _fadeTo(0.0, const Duration(milliseconds: 200));
        case BreathSessionStatus.breath:
          // Also load the phase asset if it hasn't been loaded yet (e.g. very
          // first breath transition — phase branch never fired while paused).
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

    // 3. Phase changes
    if (state.phase != _currentPhase) {
      _currentPhase = state.phase;
      if (_phaseAssets.containsKey(state.phase)) {
        unawaited(_switchToPhase(state.phase));
      } else {
        _fadeTo(0.0, const Duration(milliseconds: 500));
      }
      return;
    }

    // 4. End-of-phase fade-out trigger
    if (_currentStatus == BreathSessionStatus.breath &&
        _phaseAssets.containsKey(state.phase) &&
        state.remainingTicks > 0 &&
        state.remainingTicks <= 3) {
      final intervalMs = state.currentIntervalMs > 0 ? state.currentIntervalMs : 1000;
      _fadeTo(0.0, Duration(milliseconds: state.remainingTicks * intervalMs));
    }
  }

  Future<void> _switchToPhase(BreathPhase phase) async {
    final gen = ++_switchGen;
    final asset = _phaseAssets[phase];
    if (asset == null) return;
    final player = _player;
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
    final player = _player;
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
