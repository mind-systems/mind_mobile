import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'package:mind/Biometrics/IHeartRateSource.dart';
import 'package:mind/Biometrics/Models/CardioData.dart';
import 'ITickCadenceSource.dart';

/// [ITickCadenceSource] implementation backed by [IHeartRateSource].
///
/// Derives tick cadence from heart rate BPM using the formula
/// `(60000 / heartRate).round()` — no moving average is applied because BPM
/// is already an SDK-side average; stacking another would lag the live signal.
///
/// HR is a cadence source, NOT a synthetic IRrIntervalSource injected into
/// ActiveRrSource. SDK quality flags ([CardioData.metricsAvailable] and
/// [CardioData.hasArtifacts]) are trusted as-is with no additional RR cleaning
/// or plausibility filtering.
///
/// Arms a grace timer on every valid sample. If no valid sample arrives within
/// [graceWindow] (default 10 s), [isUsable] flips to `false` and
/// [SwitchableTickService] auto-falls back to [ClockTickService]. The last
/// computed period is retained (coasting) — not reset — so that a reconnecting
/// sensor restores cadence without a gap.
///
/// Does **not** dispose the injected [IHeartRateSource] — it is an App-owned
/// singleton shared with other consumers.
class HeartRateTickCadenceSource implements ITickCadenceSource {
  HeartRateTickCadenceSource(
    IHeartRateSource heartRateSource, {
    Duration graceWindow = const Duration(seconds: 10),
    Timer Function(Duration, void Function()) timerFactory = Timer.new,
  })  : _graceWindow = graceWindow,
        _timerFactory = timerFactory {
    _isUsable = BehaviorSubject<bool>.seeded(false);
    _periodSubject = BehaviorSubject<int>();
    _cardioSub = heartRateSource.cardioStream.listen(_onCardio);
  }

  final Duration _graceWindow;
  final Timer Function(Duration, void Function()) _timerFactory;

  late final BehaviorSubject<bool> _isUsable;
  late final BehaviorSubject<int> _periodSubject;
  int? _currentPeriodMs;
  Timer? _graceTimer;
  StreamSubscription<CardioData>? _cardioSub;

  // ── ITickCadenceSource ──────────────────────────────────────────────────────

  @override
  Stream<int> get smoothedPeriodMs => _periodSubject.stream;

  @override
  int? get currentPeriodMs => _currentPeriodMs;

  @override
  bool get isUsable => _isUsable.value;

  @override
  Stream<bool> get usableChanges => _isUsable.stream;

  @override
  void dispose() {
    _cardioSub?.cancel();
    _graceTimer?.cancel();
    _isUsable.close();
    _periodSubject.close();
    // Does NOT dispose the injected IHeartRateSource — App-owned singleton.
  }

  // ── Cardio subscription ─────────────────────────────────────────────────────

  void _onCardio(CardioData data) {
    if (!data.metricsAvailable || data.hasArtifacts || data.heartRate <= 0) {
      return;
    }

    final periodMs = (60000 / data.heartRate).round();
    _currentPeriodMs = periodMs;
    _periodSubject.add(periodMs);

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
    // Period is NOT reset — metronome coasts at the last known period.
  }
}
