import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'ActiveRrSource.dart';
import 'Models/RrInterval.dart';

/// Always-on derived-metric layer over [ActiveRrSource] that exposes a
/// **simple moving average** of the last [window] non-artifact RR intervals.
///
/// Lives as an App-singleton so the moving average accumulates continuously
/// from app launch, warming up before any breathing session opens. Pure Dart —
/// no breath-module or tick-service knowledge.
///
/// The [smoothedIntervalStream] is a [BehaviorSubject] that replays its last
/// value to new subscribers **only when it has a value** (i.e., after the
/// first non-artifact interval has been accepted). This replay behaviour is
/// load-bearing for [HeartRateTickService]'s conditional warm/cold guard.
///
/// Artifact filter: this is the filter slot reserved in [ActiveRrSource] docs.
/// Silently skips any interval where [RrInterval.isArtifact] is true; does
/// NOT log them here — [ActiveRrSource] already logs every artifact.
///
/// Window size: 3 beats keeps the cadence close to the live heart rate — a
/// larger window (7/9) smooths more but lags noticeably behind the heart.
class SmoothedRrSource {
  SmoothedRrSource(ActiveRrSource source, {int window = _defaultWindow})
      : _source = source,
        _window = window {
    _sub = source.stream.listen(_onInterval);
  }

  static const int _defaultWindow = 3;

  final ActiveRrSource _source;
  final int _window;
  final List<int> _samples = [];

  // Unseeded — hasValue is false until the first non-artifact interval lands.
  final _subject = BehaviorSubject<int>();
  StreamSubscription<RrInterval>? _sub;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Current simple moving average in milliseconds. `null` before the first
  /// non-artifact interval has been accepted since app launch.
  int? get smoothedIntervalMs => _subject.hasValue ? _subject.value : null;

  /// Emits once per accepted (non-artifact) RR interval. Replays the last
  /// value to new subscribers only when the subject already has a value.
  Stream<int> get smoothedIntervalStream => _subject.stream;

  /// Pass-through: whether [ActiveRrSource] currently has an active source.
  bool get hasActiveSource => _source.hasActiveSource;

  /// Pass-through: transitions of [hasActiveSource].
  Stream<bool> get hasActiveSourceStream => _source.hasActiveSourceStream;

  // ── Internal ───────────────────────────────────────────────────────────────

  void _onInterval(RrInterval rr) {
    if (rr.isArtifact) return; // silently skip — ActiveRrSource already logged it

    _samples.add(rr.intervalMs);
    if (_samples.length > _window) {
      _samples.removeAt(0);
    }

    final sma = (_samples.reduce((a, b) => a + b) / _samples.length).round();
    _subject.add(sma);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _subject.close();
    // Does NOT dispose _source — owned by App, never disposed.
  }
}
