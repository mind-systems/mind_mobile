import 'dart:async';

import 'package:breath_module/breath_module.dart' show ITickService, TickData, TickSource;

import 'TickCadence/ITickCadenceSource.dart';

/// Dumb metronome tick source whose period tracks an [ITickCadenceSource].
///
/// All RR staleness, grace-window, and usability logic has been extracted into
/// [ITickCadenceSource] implementations (see [RrTickCadenceSource] and
/// [TickCadenceSelector]). This class is now responsible only for:
///
/// - Seeding [_currentPeriodMs] synchronously at construction from
///   [ITickCadenceSource.currentPeriodMs] (preserves the warm-path byte-for-byte
///   behaviour of the old [HeartRateTickService]).
/// - Running a free-running, self-rescheduling metronome at [_currentPeriodMs].
/// - Delegating [hasActiveSource] / [hasActiveSourceStream] to the cadence source.
///
/// Real heartbeats **never** emit ticks — only the metronome does.
///
/// Mirrors [ClockTickService] exactly: started at construction via [start],
/// no prime/immediate tick, no pause/lifecycle subscription.
class HeartRateTickService implements ITickService {
  HeartRateTickService({
    required ITickCadenceSource cadence,
    Timer Function(Duration, void Function()) timerFactory = Timer.new,
  })  : _cadence = cadence,
        _timerFactory = timerFactory {
    // Seed the metronome period synchronously — no async emission needed.
    // Preserves the warm-path behaviour where the old constructor read
    // smoothedRrSource.smoothedIntervalMs ?? 1000 before subscribing.
    _currentPeriodMs = cadence.currentPeriodMs ?? 1000;

    // Subscribe to ongoing period updates from the cadence source.
    _cadenceSub = cadence.smoothedPeriodMs.listen((ms) => _currentPeriodMs = ms);
  }

  final ITickCadenceSource _cadence;
  final Timer Function(Duration, void Function()) _timerFactory;

  final StreamController<TickData> _tickController =
      StreamController<TickData>.broadcast();

  int _currentPeriodMs = 1000;
  Timer? _metronome;
  StreamSubscription<int>? _cadenceSub;

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

  // ── Availability (delegated to cadence source) ────────────────────────────

  /// Whether the cadence source is currently usable.
  bool get hasActiveSource => _cadence.isUsable;

  /// Transitions of [hasActiveSource]. Seeded [BehaviorSubject] stream —
  /// [SwitchableTickService] relies on receiving the current value on subscribe.
  Stream<bool> get hasActiveSourceStream => _cadence.usableChanges;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Starts the free-running metronome. Call once at construction, mirroring
  /// `ClockTickService()..simulateTick()`. No prime/immediate tick is emitted.
  void start() {
    _scheduleNext();
  }

  @override
  void dispose() {
    _metronome?.cancel();
    _cadenceSub?.cancel();
    _tickController.close();
    // Dispose the cadence source — this class received the dependency so it
    // owns the lifecycle (RULES.md rule 3). The chain is:
    //   SwitchableTickService.dispose → _heart.dispose → selector.dispose → rrCadence.dispose
    // rrCadence.dispose does NOT touch the App-owned SmoothedRrSource singleton.
    _cadence.dispose();
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
}
