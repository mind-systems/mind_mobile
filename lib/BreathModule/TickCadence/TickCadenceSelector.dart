import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'ITickCadenceSource.dart';

/// Priority-ordered selector over a list of [ITickCadenceSource]s.
///
/// All sources are subscribed to simultaneously at construction (kept warm in
/// parallel). The active source is the lowest-index source whose [isUsable] is
/// `true`. When no source is usable, the active source is `null` and
/// [currentPeriodMs] falls back to `sources.first.currentPeriodMs`.
///
/// With a single source this is a transparent pass-through — behavior is
/// identical to wiring [HeartRateTickService] directly to that source.
///
/// [usableChanges] is a seeded [BehaviorSubject] stream so that
/// [SwitchableTickService] receives the current state on subscribe (mirrors the
/// former `_effectiveActive.stream`).
///
/// `dispose()` cancels all subscriptions and disposes every child source.
class TickCadenceSelector implements ITickCadenceSource {
  TickCadenceSelector(List<ITickCadenceSource> sources) : _sources = List.unmodifiable(sources) {
    // Seed the usable subject before subscribing so _reSelect can check it.
    _isUsable = BehaviorSubject<bool>.seeded(_anyUsable());

    // Subscribe to every source's usableChanges.
    // The BehaviorSubject replay is delivered asynchronously (microtask), so
    // _reSelect first runs after the constructor returns. This is safe:
    // _isUsable is seeded directly from _anyUsable() above and currentPeriodMs
    // falls back to _sources.first for the window before _reSelect resolves
    // _activeSource (see [currentPeriodMs]).
    for (final source in _sources) {
      _subs.add(source.usableChanges.listen((_) => _reSelect()));
    }
  }

  final List<ITickCadenceSource> _sources;
  final List<StreamSubscription<bool>> _subs = [];
  StreamSubscription<int>? _activePipeSub;

  final StreamController<int> _periodController = StreamController<int>.broadcast();
  late final BehaviorSubject<bool> _isUsable;

  ITickCadenceSource? _activeSource;

  // ── ITickCadenceSource ──────────────────────────────────────────────────────

  @override
  Stream<int> get smoothedPeriodMs => _periodController.stream;

  /// Delegates to the currently-selected source. When no source is usable,
  /// falls back to `sources.first.currentPeriodMs` (with a single source this
  /// is always [RrTickCadenceSource.currentPeriodMs], preserving the
  /// construction-time seed for the metronome).
  ///
  /// TODO(note-164): With a second source (HR) the fallback should prefer
  /// the highest-priority source that has a non-null snapshot rather than
  /// unconditionally using sources.first. Revisit when HR source is added.
  @override
  int? get currentPeriodMs => (_activeSource ?? _sources.first).currentPeriodMs;

  @override
  bool get isUsable => _isUsable.value;

  @override
  Stream<bool> get usableChanges => _isUsable.stream;

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _activePipeSub?.cancel();
    if (!_periodController.isClosed) _periodController.close();
    _isUsable.close();
    for (final source in _sources) {
      source.dispose();
    }
  }

  // ── Selection ───────────────────────────────────────────────────────────────

  bool _anyUsable() => _sources.any((s) => s.isUsable);

  void _reSelect() {
    // Find the first usable source (lowest-index priority).
    ITickCadenceSource? next;
    for (final source in _sources) {
      if (source.isUsable) {
        next = source;
        break;
      }
    }

    if (identical(next, _activeSource)) {
      // Active source is unchanged — only update the usable subject if needed.
      _syncUsable();
      return;
    }

    _activeSource = next;

    // Re-pipe smoothedPeriodMs from the new active source.
    _activePipeSub?.cancel();
    _activePipeSub = null;
    if (next != null) {
      _activePipeSub = next.smoothedPeriodMs.listen((ms) {
        if (!_periodController.isClosed) _periodController.add(ms);
      });
    }

    _syncUsable();
  }

  void _syncUsable() {
    final nowUsable = _anyUsable();
    if (!_isUsable.isClosed && _isUsable.value != nowUsable) {
      _isUsable.add(nowUsable);
    }
  }
}
