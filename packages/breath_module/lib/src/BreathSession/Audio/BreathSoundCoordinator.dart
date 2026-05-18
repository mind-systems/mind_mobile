import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../CommonModels/TickSource.dart';
import '../Models/BreathSessionState.dart';
import '../BreathSessionViewModel.dart';

String _ts() {
  final now = DateTime.now();
  final ms = now.millisecond.toString().padLeft(3, '0');
  return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.$ms';
}

class BreathSoundCoordinator {
  final BreathViewModel viewModel;

  AudioPlayer? _loopPlayerA;
  AudioPlayer? _loopPlayerB;
  AudioPlayer? _activeLoop;
  AudioPlayer? _inactiveLoop;
  AudioPlayer? _tickPlayer;
  StreamSubscription<void>? _tickSub;
  TickSource _currentTickSource = TickSource.timer;

  void Function()? _stateListener;
  BreathPhase? _currentPhase;
  BreathSessionStatus? _currentStatus;
  Timer? _fadeTimerA;
  Timer? _fadeTimerB;
  int _switchGen = 0;
  Future<void>? _loadFuture;

  static const Map<BreathPhase, String> _phaseAssets = {
    BreathPhase.inhale: 'assets/audio/ohm_inhale.ogg',
    BreathPhase.exhale: 'assets/audio/ohm_exhale.ogg',
    BreathPhase.hold:   'assets/audio/ohm_hold.ogg',
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

  BreathSoundCoordinator({required this.viewModel});

  void initialize(BreathSessionState initialState) {
    if (_loopPlayerA != null) return;
    if (kDebugMode) debugPrint('${_ts()} [Sound] initialize start');
    _loopPlayerA = AudioPlayer();
    _loopPlayerB = AudioPlayer();
    unawaited(_loopPlayerA!.setLoopMode(LoopMode.one));
    unawaited(_loopPlayerA!.setVolume(0.0));
    unawaited(_loopPlayerB!.setLoopMode(LoopMode.one));
    unawaited(_loopPlayerB!.setVolume(0.0));
    final sources = _phaseOrder.map((p) => AudioSource.asset(_phaseAssets[p]!)).toList();
    _loadFuture = Future.wait<void>([
      _loopPlayerA!.setAudioSources(sources, preload: true),
      _loopPlayerB!.setAudioSources(sources, preload: true),
    ]).then((_) {
      if (kDebugMode) debugPrint('${_ts()} [Sound] loadFuture resolved — both players ready');
    });
    unawaited(_loadFuture!);
    _activeLoop = _loopPlayerA;
    _inactiveLoop = _loopPlayerB;
    if (kDebugMode) debugPrint('${_ts()} [Sound] initialize: activeLoop=A inactiveLoop=B loadFuture started');

    _currentTickSource = initialState.tickSource;
    _tickPlayer = AudioPlayer();
    unawaited(_loadTickAsset(_currentTickSource));

    _tickSub = viewModel.tickStream.listen((_) => _onTick());
    _stateListener = viewModel.listen(_onStateChanged);
  }

  void reset() {
    _fadeTimerA?.cancel();
    _fadeTimerA = null;
    _fadeTimerB?.cancel();
    _fadeTimerB = null;
    for (final player in [_loopPlayerA, _loopPlayerB]) {
      if (player != null) {
        unawaited(player.stop());
        unawaited(player.setVolume(0.0));
      }
    }
    _activeLoop = _loopPlayerA;
    _inactiveLoop = _loopPlayerB;
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
    _fadeTimerA?.cancel();
    _fadeTimerA = null;
    _fadeTimerB?.cancel();
    _fadeTimerB = null;
    _stateListener?.call();
    _stateListener = null;
    final playerA = _loopPlayerA;
    final playerB = _loopPlayerB;
    _loopPlayerA = null;
    _loopPlayerB = null;
    _activeLoop = null;
    _inactiveLoop = null;
    if (playerA != null) {
      unawaited(playerA.dispose());
    }
    if (playerB != null) {
      unawaited(playerB.dispose());
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
      final prev = _currentStatus;
      _currentStatus = state.status;
      if (kDebugMode) debugPrint('${_ts()} [Sound] status: $prev → ${state.status}  phase=${state.phase}  active=${_activeLoop == _loopPlayerA ? "A" : "B"}  volA=${_loopPlayerA?.volume.toStringAsFixed(2)}  volB=${_loopPlayerB?.volume.toStringAsFixed(2)}');
      switch (state.status) {
        case BreathSessionStatus.pause:
          if (_activeLoop != null) _fadePlayer(_activeLoop!, 0.0, const Duration(milliseconds: 200));
        case BreathSessionStatus.breath:
          if (_phaseAssets.containsKey(state.phase) && state.phase != _currentPhase) {
            _currentPhase = state.phase;
            final intervalMs = state.currentIntervalMs > 0 ? state.currentIntervalMs : 1000;
            unawaited(_switchToPhase(state.phase, Duration(milliseconds: intervalMs)));
          } else {
            if (_activeLoop != null) _fadePlayer(_activeLoop!, 1.0, const Duration(milliseconds: 200));
          }
        case BreathSessionStatus.complete:
        case BreathSessionStatus.rest:
          if (_activeLoop != null) _fadePlayer(_activeLoop!, 0.0, const Duration(milliseconds: 500));
      }
      return;
    }

    // 4. Phase changes
    if (state.phase != _currentPhase) {
      final prev = _currentPhase;
      _currentPhase = state.phase;
      if (kDebugMode) debugPrint('${_ts()} [Sound] phase: $prev → ${state.phase}  remaining=${state.remainingTicks}  active=${_activeLoop == _loopPlayerA ? "A" : "B"}  volA=${_loopPlayerA?.volume.toStringAsFixed(2)}  volB=${_loopPlayerB?.volume.toStringAsFixed(2)}');
      if (_phaseAssets.containsKey(state.phase)) {
        final intervalMs = state.currentIntervalMs > 0 ? state.currentIntervalMs : 1000;
        unawaited(_switchToPhase(state.phase, Duration(milliseconds: intervalMs)));
      } else {
        if (_activeLoop != null) _fadePlayer(_activeLoop!, 0.0, const Duration(milliseconds: 500));
      }
      return;
    }
  }

  Future<void> _loadTickAsset(TickSource source) async {
    final player = _tickPlayer;
    if (player == null) return;
    await player.setAsset(_tickAssets[source]!);
  }

  void _onTick() {
    final allowTick = _currentStatus == BreathSessionStatus.pause ||
        _currentStatus == BreathSessionStatus.rest ||
        (_currentStatus == BreathSessionStatus.breath &&
            _currentPhase == BreathPhase.rest);
    if (kDebugMode) debugPrint('${_ts()} [Sound] _onTick  status=$_currentStatus  phase=$_currentPhase  allowed=$allowTick');
    if (!allowTick) return;
    final player = _tickPlayer;
    if (player == null) return;
    unawaited(player.seek(Duration.zero).then((_) => player.play()));
  }

  Future<void> _switchToPhase(BreathPhase phase, Duration fadeDuration) async {
    final gen = ++_switchGen;
    final inactiveName = _inactiveLoop == _loopPlayerA ? 'A' : 'B';
    if (kDebugMode) debugPrint('${_ts()} [Sound] _switchToPhase($phase) gen=$gen  inactive=$inactiveName  fadeDuration=${fadeDuration.inMilliseconds}ms');
    if (_phaseAssets[phase] == null) return;
    final active = _activeLoop;
    final inactive = _inactiveLoop;
    if (active == null || inactive == null) return;
    final index = _phaseOrder.indexOf(phase);
    if (index == -1) return;
    // Start fading out the outgoing player immediately, before any async await,
    // so the crossfade begins at the phase boundary rather than after seek latency.
    _fadePlayer(active, 0.0, fadeDuration);
    if (kDebugMode) debugPrint('${_ts()} [Sound] _switchToPhase($phase) gen=$gen  fading old-active=${active == _loopPlayerA ? "A" : "B"} → 0.0 (early)  dur=${fadeDuration.inMilliseconds}ms');
    // Wait for the initial playlist load before issuing seek — guards against
    // cold-start and resume paths on slow Android devices where setAudioSources
    // may still be in progress.
    if (_loadFuture != null) {
      if (kDebugMode) debugPrint('${_ts()} [Sound] _switchToPhase($phase) gen=$gen  awaiting loadFuture...');
      await _loadFuture;
      if (kDebugMode) debugPrint('${_ts()} [Sound] _switchToPhase($phase) gen=$gen  loadFuture done');
    }
    // Bail out if a newer switch arrived, or if the session is no longer active.
    if (gen != _switchGen) { if (kDebugMode) debugPrint('${_ts()} [Sound] _switchToPhase($phase) gen=$gen  BAIL gen mismatch'); return; }
    if (_currentStatus != BreathSessionStatus.breath) { if (kDebugMode) debugPrint('${_ts()} [Sound] _switchToPhase($phase) gen=$gen  BAIL status=$_currentStatus'); return; }
    _cancelFadeFor(inactive);
    if (kDebugMode) debugPrint('${_ts()} [Sound] _switchToPhase($phase) gen=$gen  setVolume(0) on $inactiveName');
    await inactive.setVolume(0.0);
    if (kDebugMode) debugPrint('${_ts()} [Sound] _switchToPhase($phase) gen=$gen  seek(index=$index) on $inactiveName');
    await inactive.seek(Duration.zero, index: index);
    if (kDebugMode) debugPrint('${_ts()} [Sound] _switchToPhase($phase) gen=$gen  play() on $inactiveName');
    unawaited(inactive.play());
    if (kDebugMode) debugPrint('${_ts()} [Sound] _switchToPhase($phase) gen=$gen  play() dispatched — swapping active↔inactive');
    _activeLoop = inactive;
    _inactiveLoop = active;
    if (gen != _switchGen) { if (kDebugMode) debugPrint('${_ts()} [Sound] _switchToPhase($phase) gen=$gen  BAIL gen mismatch after play'); return; }
    if (_currentStatus != BreathSessionStatus.breath) { if (kDebugMode) debugPrint('${_ts()} [Sound] _switchToPhase($phase) gen=$gen  BAIL status=$_currentStatus after play'); return; }
    if (kDebugMode) debugPrint('${_ts()} [Sound] _switchToPhase($phase) gen=$gen  fading new-active=${_activeLoop == _loopPlayerA ? "A" : "B"} → 1.0  dur=${fadeDuration.inMilliseconds}ms');
    _fadePlayer(_activeLoop!, 1.0, fadeDuration);
  }

  void _cancelFadeFor(AudioPlayer player) {
    if (player == _loopPlayerA) {
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
        if (player == _loopPlayerA) {
          _fadeTimerA = null;
        } else {
          _fadeTimerB = null;
        }
      }
    });
    if (player == _loopPlayerA) {
      _fadeTimerA = timer;
    } else {
      _fadeTimerB = timer;
    }
  }
}
