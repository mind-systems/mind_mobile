import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'package:mind/Biometrics/SmoothedRrSource.dart';
import 'ITickCadenceSource.dart';

/// [ITickCadenceSource] implementation backed by [SmoothedRrSource].
///
/// Owns **all** RR staleness logic that previously lived in
/// [HeartRateTickService]:
///
/// - Seeds [isUsable] from [SmoothedRrSource.hasActiveSource] at construction.
/// - Arms a grace timer whenever a genuine beat is accepted. If no genuine beat
///   arrives within [graceWindow] (default 10 s), [isUsable] flips to `false`
///   and [SwitchableTickService] auto-falls back to [ClockTickService].
/// - Drops the one stale [BehaviorSubject] replay emitted by
///   [SmoothedRrSource.smoothedIntervalStream] on the warm path so it is never
///   miscounted as a genuine beat.
///
/// The metronome period itself is exposed verbatim via [smoothedPeriodMs] and
/// the synchronous snapshot [currentPeriodMs] — [HeartRateTickService] reads
/// [currentPeriodMs] once at construction to seed its timer without waiting for
/// the first async emission.
///
/// Does **not** dispose the injected [SmoothedRrSource] — it is an App-owned
/// singleton shared with other consumers.
class RrTickCadenceSource implements ITickCadenceSource {
  RrTickCadenceSource(
    SmoothedRrSource smoothedRrSource, {
    Duration graceWindow = const Duration(seconds: 10),
    Timer Function(Duration, void Function()) timerFactory = Timer.new,
  })  : _smoothedRrSource = smoothedRrSource,
        _graceWindow = graceWindow,
        _timerFactory = timerFactory {
    // Seed usable state from the current availability of the smoothed source.
    _isUsable = BehaviorSubject<bool>.seeded(smoothedRrSource.hasActiveSource);

    // Determine whether a BehaviorSubject replay is pending at subscription
    // time. A replay exists only when the subject already has a value (warm path).
    // Cold path: pre-mark as dropped so the first emission is treated as genuine.
    // Warm path: starts false so the first emission (replay) is discarded.
    final bool expectReplay = smoothedRrSource.smoothedIntervalMs != null;
    _droppedReplay = !expectReplay;

    // Arm the grace timer at construction if already active (warm path with live sensor).
    if (smoothedRrSource.hasActiveSource) {
      _armGrace();
    }

    _smoothedSub = smoothedRrSource.smoothedIntervalStream.listen(_onSmoothed);
  }

  final SmoothedRrSource _smoothedRrSource;
  final Duration _graceWindow;
  final Timer Function(Duration, void Function()) _timerFactory;

  late final BehaviorSubject<bool> _isUsable;
  bool _droppedReplay = false;
  Timer? _graceTimer;
  StreamSubscription<int>? _smoothedSub;

  // ── ITickCadenceSource ──────────────────────────────────────────────────────

  /// Pass-through of [SmoothedRrSource.smoothedIntervalStream].
  @override
  Stream<int> get smoothedPeriodMs => _smoothedRrSource.smoothedIntervalStream;

  /// Synchronous snapshot of [SmoothedRrSource.smoothedIntervalMs].
  @override
  int? get currentPeriodMs => _smoothedRrSource.smoothedIntervalMs;

  @override
  bool get isUsable => _isUsable.value;

  @override
  Stream<bool> get usableChanges => _isUsable.stream;

  @override
  void dispose() {
    _smoothedSub?.cancel();
    _graceTimer?.cancel();
    _isUsable.close();
    // Does NOT dispose _smoothedRrSource — App-owned singleton.
  }

  // ── Smoothed-RR subscription ────────────────────────────────────────────────

  void _onSmoothed(int intervalMs) {
    if (!_droppedReplay) {
      // First emission on the warm path is a stale replay — discard it.
      _droppedReplay = true;
      return;
    }

    // Genuine beat: activate (if not already) and re-arm the grace timer.
    if (!_isUsable.value) {
      _isUsable.add(true);
    }
    _armGrace();
  }

  // ── Grace timer ─────────────────────────────────────────────────────────────

  void _armGrace() {
    _graceTimer?.cancel();
    _graceTimer = _timerFactory(_graceWindow, _onGraceExpired);
  }

  void _onGraceExpired() {
    _isUsable.add(false);
    // Metronome in HeartRateTickService is NOT stopped — it coasts at the last
    // known period so a reconnecting sensor restores cadence without a gap.
  }
}
