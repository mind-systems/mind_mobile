import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../Logger.dart';
import 'IRrIntervalSource.dart';
import 'Models/RrInterval.dart';

/// Picks the **single currently-active** RR source from a static list and
/// forwards its intervals downstream. Implements preferred-with-fallback:
/// emissions go through the first source that is alive; if it falls silent
/// past the watchdog window, switches to the next alive source; if none are
/// alive, [hasActiveSource] flips to false and the stream goes quiet until a
/// source revives.
///
/// **Not** for the server pipeline — that one uses [BioStreamRouter] which
/// merges all sources unconditionally (every sample carries a `source` tag
/// and aggregation is server-side). This class is for client consumers that
/// need a single coherent RR cadence (tick source, pulse animations).
///
/// Artifacts (`RrInterval.isArtifact == true`) are forwarded as-is in MVP —
/// logged but not filtered. Animation runs after a beat using the just-passed
/// interval as a prediction of the next; in calm sitting state ≥3× swings
/// are rare and forwarding raw data is acceptable while we observe real
/// behavior. The filter slot is intentionally easy to add later (one branch
/// in `_onInterval`).
class ActiveRrSource {
  ActiveRrSource(
    List<IRrIntervalSource> sources, {
    DateTime Function() clock = DateTime.now,
    Timer Function(Duration, void Function()) timerFactory = Timer.new,
  })  : _sources = List.unmodifiable(sources),
        _clock = clock,
        _timerFactory = timerFactory {
    for (var i = 0; i < _sources.length; i++) {
      final index = i;
      _subs.add(_sources[i].rrStream.listen((rr) => _onInterval(index, rr)));
    }
  }

  static const Duration _silenceFloor = Duration(seconds: 2);
  static const double _silenceMultiplier = 2.0;

  final List<IRrIntervalSource> _sources;
  final DateTime Function() _clock;
  final Timer Function(Duration, void Function()) _timerFactory;
  final List<StreamSubscription<RrInterval>> _subs = [];

  final _intervalController = StreamController<RrInterval>.broadcast();
  final _hasActiveController = BehaviorSubject<bool>.seeded(false);

  /// The last interval timestamp received from each source (by index). Used
  /// by the watchdog to compute silence per source.
  final Map<int, DateTime> _lastSeenAt = {};
  int? _activeIndex;
  int? _lastIntervalMs;
  Timer? _watchdog;

  /// Intervals from the currently-active source. Broadcast — multiple
  /// consumers (tick service, future pulse widget) can subscribe.
  Stream<RrInterval> get stream => _intervalController.stream;

  /// `true` when at least one source has emitted within the silence window.
  /// Recomputed by the watchdog and on every received interval.
  bool get hasActiveSource => _hasActiveController.value;

  /// Emits on every transition of [hasActiveSource]. `BehaviorSubject` —
  /// late subscribers receive the current value immediately.
  Stream<bool> get hasActiveSourceStream => _hasActiveController.stream;

  void _onInterval(int index, RrInterval rr) {
    _lastSeenAt[index] = _clock();
    if (rr.isArtifact) {
      logPrint('ActiveRrSource: artifact from source[$index] (${rr.source.name}), intervalMs=${rr.intervalMs}');
    }
    if (_activeIndex == null || index < _activeIndex!) {
      // Either no active source yet, or a higher-priority source revived.
      _activeIndex = index;
      logPrint('ActiveRrSource: active source = $index (${rr.source.name})');
    }
    if (index != _activeIndex) return; // only forward active-source intervals
    _lastIntervalMs = rr.intervalMs;
    _intervalController.add(rr);
    _ensureHasActive(true);
    _restartWatchdog();
  }

  void _restartWatchdog() {
    _watchdog?.cancel();
    final base = _lastIntervalMs ?? 1000;
    final window = Duration(milliseconds: (base * _silenceMultiplier).round());
    final effective = window > _silenceFloor ? window : _silenceFloor;
    _watchdog = _timerFactory(effective, _onSilence);
  }

  void _onSilence() {
    // Active source went silent — try the next-priority source that has
    // emitted recently. Walk the full list in priority order.
    final now = _clock();
    int? next;
    for (var i = 0; i < _sources.length; i++) {
      if (i == _activeIndex) continue;
      final lastSeen = _lastSeenAt[i];
      if (lastSeen == null) continue;
      if (now.difference(lastSeen) <= _silenceFloor) {
        next = i;
        break;
      }
    }
    if (next != null) {
      logPrint('ActiveRrSource: failover $_activeIndex → $next');
      _activeIndex = next;
      _restartWatchdog();
      return;
    }
    logPrint('ActiveRrSource: all sources silent');
    _activeIndex = null;
    _lastIntervalMs = null;
    _ensureHasActive(false);
  }

  void _ensureHasActive(bool value) {
    if (_hasActiveController.value != value) {
      _hasActiveController.add(value);
    }
  }

  Future<void> dispose() async {
    _watchdog?.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    await _intervalController.close();
    await _hasActiveController.close();
  }
}
