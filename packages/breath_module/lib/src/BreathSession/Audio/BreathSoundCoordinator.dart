import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mind_audio/mind_audio.dart';
import '../../CommonModels/TickSource.dart';
import '../Models/BreathSessionState.dart';
import '../BreathSessionViewModel.dart';

class BreathSoundCoordinator {
  final BreathViewModel viewModel;
  final AudioLooper _looper;
  final AudioOneShot _oneShot;
  final AudioCatalog _catalog;

  StreamSubscription<void>? _tickSub;
  TickSource _currentTickSource = TickSource.timer;

  void Function()? _stateListener;
  BreathPhase? _currentPhase;
  BreathSessionStatus? _currentStatus;
  bool _isSuspended = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  final ValueNotifier<bool> isMuted = ValueNotifier(false);

  static const Map<BreathPhase, String> _phaseAssets = {
    BreathPhase.inhale: 'assets/audio/ohm_inhale.flac',
    BreathPhase.exhale: 'assets/audio/ohm_exhale.flac',
    BreathPhase.hold:   'assets/audio/ohm_hold.flac',
    // rest → silence (no entry)
  };

  // Fixed order for the preloaded playlist — index 0=inhale, 1=exhale, 2=hold.
  // rest is intentionally absent (silence, no loop needed).
  static const List<BreathPhase> _phaseOrder = [
    BreathPhase.inhale,
    BreathPhase.exhale,
    BreathPhase.hold,
  ];

  static const Map<TickSource, String> _tickAssets = {
    TickSource.timer:     'assets/audio/tick_clock.ogg',
    TickSource.heartbeat: 'assets/audio/tick_heartbeat.ogg',
  };

  // Adaptive crossfade formula: fadeMs = (_kFadeCoeff * pow(nextPhaseMs, 0.65)).clamp(_kMinFadeMs, _kMaxFadeMs)
  // Reference table (actual values produced by these constants):
  //   1s phase  → 341ms
  //   2s phase  → 536ms
  //   3s phase  → 706ms
  //   4s phase  → 843ms
  //   8s phase  → 1320ms
  //   ~10.5s+   → 1500ms (capped)
  static const double _kFadeCoeff = 3.83;
  static const int _kMinFadeMs = 150;
  static const int _kMaxFadeMs = 1500;

  BreathSoundCoordinator({
    required this.viewModel,
    required AudioLooper looper,
    required AudioOneShot oneShot,
    AudioCatalog? catalog,
  })  : _looper = looper,
        _oneShot = oneShot,
        _catalog = catalog ?? AssetAudioCatalog();

  Duration _computeFadeDuration(BreathSessionState state) {
    final intervalMs = state.currentIntervalMs > 0 ? state.currentIntervalMs : 1000;
    final phaseTicks = state.currentPhaseTotalDuration;
    // Guard: if phase length is unknown/non-positive, fall back to one tick interval.
    if (phaseTicks <= 0) {
      return Duration(milliseconds: intervalMs.clamp(_kMinFadeMs, _kMaxFadeMs));
    }
    final nextPhaseMs = phaseTicks * intervalMs;
    final raw = _kFadeCoeff * pow(nextPhaseMs.toDouble(), 0.65);
    final clamped = raw.clamp(_kMinFadeMs.toDouble(), _kMaxFadeMs.toDouble()).toInt();
    return Duration(milliseconds: clamped);
  }

  void initialize(BreathSessionState initialState) {
    if (_isInitialized) return;
    _isInitialized = true;
    _currentTickSource = initialState.tickSource;
    unawaited(_initAudio());
  }

  Future<void> _initAudio() async {
    final sources = await Future.wait(
      _phaseOrder.map((p) => _catalog.sourceFor(AudioTrack(_phaseAssets[p]!))),
    );
    if (_isDisposed) return;
    unawaited(_looper.initialize(sources));
    unawaited(_oneShot.load(AudioTrack(_tickAssets[_currentTickSource]!)));
    _tickSub = viewModel.tickStream.listen((_) => _onTick());
    _stateListener = viewModel.listen(_onStateChanged);
    _onStateChanged(viewModel.currentState);
  }

  void reset() {
    _looper.stop();
    _oneShot.stop();
    _currentPhase = null;
    _currentStatus = null;
  }

  void toggleMute() {
    isMuted.value = !isMuted.value;
    if (!_isInitialized) return;
    if (isMuted.value) {
      _looper.fadeOut(const Duration(milliseconds: 300));
      _oneShot.stop();
    } else {
      if (_currentStatus == BreathSessionStatus.breath &&
          _currentPhase != null &&
          _phaseAssets.containsKey(_currentPhase)) {
        _looper.crossfadeTo(
          _phaseOrder.indexOf(_currentPhase!),
          const Duration(milliseconds: 300),
        );
      }
    }
  }

  void dispose() {
    _isDisposed = true;
    _tickSub?.cancel();
    _tickSub = null;
    _stateListener?.call();
    _stateListener = null;
    _looper.dispose();
    _oneShot.dispose();
    isMuted.dispose();
  }

  void suspend() {
    _isSuspended = true;
    _oneShot.stop();
  }

  void resume() {
    _isSuspended = false;
  }

  void _onStateChanged(BreathSessionState state) {
    // 1. Load gate
    if (state.loadState != SessionLoadState.ready) return;

    // 2. Tick-source change (stable within a session; guard for correctness across restarts)
    if (state.tickSource != _currentTickSource) {
      _currentTickSource = state.tickSource;
      unawaited(_oneShot.load(AudioTrack(_tickAssets[_currentTickSource]!)));
    }

    // 3. Status changes
    if (state.status != _currentStatus) {
      _currentStatus = state.status;
      // Track phase unconditionally so toggleMute restores the correct track.
      final bool phaseChangedForBreath = state.status == BreathSessionStatus.breath &&
          _phaseAssets.containsKey(state.phase) &&
          state.phase != _currentPhase;
      if (phaseChangedForBreath) _currentPhase = state.phase;
      if (!isMuted.value) {
        switch (state.status) {
          case BreathSessionStatus.pause:
            _looper.fadeOut(const Duration(milliseconds: 200));
          case BreathSessionStatus.breath:
            if (phaseChangedForBreath) {
              final fadeDuration = _computeFadeDuration(state);
              _looper.crossfadeTo(_phaseOrder.indexOf(state.phase), fadeDuration);
            } else {
              _looper.fadeIn(const Duration(milliseconds: 200));
            }
          case BreathSessionStatus.complete:
          case BreathSessionStatus.rest:
            _looper.fadeOut(const Duration(milliseconds: 500));
        }
      }
      return;
    }

    // 4. Phase changes
    if (state.phase != _currentPhase) {
      _currentPhase = state.phase;
      if (!isMuted.value) {
        if (_phaseAssets.containsKey(state.phase)) {
          final fadeDuration = _computeFadeDuration(state);
          _looper.crossfadeTo(_phaseOrder.indexOf(state.phase), fadeDuration);
        } else {
          _looper.fadeOut(const Duration(milliseconds: 500));
        }
      }
      return;
    }
  }

  void _onTick() {
    if (_isSuspended) return;
    if (isMuted.value) return;
    final allowTick = _currentStatus == BreathSessionStatus.pause ||
        _currentStatus == BreathSessionStatus.rest ||
        (_currentStatus == BreathSessionStatus.breath &&
            _currentPhase == BreathPhase.rest);
    if (!allowTick) return;
    _oneShot.play();
  }
}
