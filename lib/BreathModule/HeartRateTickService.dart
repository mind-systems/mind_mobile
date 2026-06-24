import 'dart:async';

import 'package:breath_module/breath_module.dart' show ITickService, TickData, TickSource;
import 'package:rxdart/rxdart.dart';

import 'package:mind/Biometrics/SmoothedRrSource.dart';

/// Tick source driven by a free-running cadence metronome whose period equals
/// the [SmoothedRrSource] simple moving average.
///
/// Real heartbeats **never** emit ticks — they only update [_currentPeriodMs]
/// and reset the grace timer. This eliminates the double-count hazard that
/// exists when a late beat arrives immediately after a synthesized one.
///
/// The metronome is a **one-shot timer that reschedules itself** after each
/// fire at the current [_currentPeriodMs]. This lets the cadence update on
/// every genuine beat without restarting from scratch.
///
/// Grace window: if no genuine beat arrives within the grace window (default 10 s),
/// [_effectiveActive] flips to false. [SwitchableTickService] reacts and
/// auto-falls back to [ClockTickService]. The metronome is NOT stopped — it
/// coasts at the last known period so a reconnecting sensor restores the cadence
/// without a gap in ticks.
///
/// Mirrors [ClockTickService] exactly: started at construction via [start],
/// no prime/immediate tick, no pause/lifecycle subscription.
class HeartRateTickService implements ITickService {
  HeartRateTickService({
    required SmoothedRrSource smoothedRrSource,
    Timer Function(Duration, void Function()) timerFactory = Timer.new,
    Duration graceWindow = const Duration(seconds: 10),
  })  : _timerFactory = timerFactory,
        _graceWindow = graceWindow {
    // Seed effective-active from the current availability of the smoothed source.
    _effectiveActive = BehaviorSubject<bool>.seeded(smoothedRrSource.hasActiveSource);

    // Determine whether a BehaviorSubject replay is pending at subscription time.
    // A replay exists only when the subject already has a value (warm path).
    final bool expectReplay = smoothedRrSource.smoothedIntervalMs != null;
    // _droppedReplay tracks whether the one stale replay has already been consumed.
    // Cold path: pre-mark as dropped (true) so the first emission is treated as genuine.
    // Warm path: starts false so the first emission (replay) is dropped.
    _droppedReplay = !expectReplay;

    // Seed the metronome period from whatever SMA is available right now.
    _currentPeriodMs = smoothedRrSource.smoothedIntervalMs ?? 1000;

    // Arm grace timer at construction if already active (warm path with live sensor).
    if (smoothedRrSource.hasActiveSource) {
      _armGrace();
    }

    _smoothedSub = smoothedRrSource.smoothedIntervalStream.listen(_onSmoothed);
  }

  final Duration _graceWindow;
  final Timer Function(Duration, void Function()) _timerFactory;

  late final BehaviorSubject<bool> _effectiveActive;
  final StreamController<TickData> _tickController =
      StreamController<TickData>.broadcast();

  bool _droppedReplay = false;
  int _currentPeriodMs = 1000;

  Timer? _metronome;
  Timer? _graceTimer;
  StreamSubscription<int>? _smoothedSub;

  // ── ITickService ────────────────────────────────────────────────────────────

  @override
  Stream<TickData> get tickStream => _tickController.stream;

  @override
  TickSource get source => TickSource.heartbeat;

  @override
  int get nominalIntervalMs => 1000;

  @override
  Stream<TickSource> get sourceChanges => const Stream.empty();

  @override
  bool trySwitchTo(TickSource target) => false;

  // ── Availability (read by SwitchableTickService) ───────────────────────────

  bool get hasActiveSource => _effectiveActive.value;
  Stream<bool> get hasActiveSourceStream => _effectiveActive.stream;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Starts the free-running metronome. Call once at construction, mirroring
  /// `ClockTickService()..simulateTick()`. No prime/immediate tick is emitted.
  void start() {
    _scheduleNext();
  }

  @override
  void dispose() {
    _metronome?.cancel();
    _graceTimer?.cancel();
    _smoothedSub?.cancel();
    _tickController.close();
    _effectiveActive.close();
    // Does NOT dispose the App-owned SmoothedRrSource — shared with other consumers.
  }

  // ── Metronome ───────────────────────────────────────────────────────────────

  // Clamp the period to a sane physiological range (250–3000 ms) so a
  // near-zero non-artifact SMA cannot spin the self-rescheduling metronome
  // into a busy-loop that floods _tickController for the rest of the session.
  static const int _periodFloorMs = 250;
  static const int _periodCeilMs = 3000;

  void _scheduleNext() {
    final clamped = _currentPeriodMs.clamp(_periodFloorMs, _periodCeilMs);
    _metronome = _timerFactory(
      Duration(milliseconds: clamped),
      _onMetronomeFire,
    );
  }

  void _onMetronomeFire() {
    _tickController.add(TickData(_currentPeriodMs.clamp(_periodFloorMs, _periodCeilMs)));
    _scheduleNext(); // reschedule at the current (possibly updated) period
  }

  // ── Smoothed-RR subscription ────────────────────────────────────────────────

  void _onSmoothed(int intervalMs) {
    if (!_droppedReplay) {
      // First emission on the warm path is a stale replay — discard it.
      _droppedReplay = true;
      return;
    }

    // Genuine beat: update period, activate, reset grace.
    _currentPeriodMs = intervalMs;
    if (!_effectiveActive.value) {
      _effectiveActive.add(true);
    }
    _armGrace();
  }

  // ── Grace timer ─────────────────────────────────────────────────────────────

  void _armGrace() {
    _graceTimer?.cancel();
    _graceTimer = _timerFactory(_graceWindow, _onGraceExpired);
  }

  void _onGraceExpired() {
    _effectiveActive.add(false);
    // Metronome is NOT stopped — coasts at the last known period.
  }
}
