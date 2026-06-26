/// Contract for tick cadence sources consumed by [HeartRateTickService].
///
/// An implementation owns all logic related to deciding whether a cadence signal
/// is currently trustworthy ([isUsable]) and what its current period is
/// ([smoothedPeriodMs], [currentPeriodMs]).
///
/// [usableChanges] **must** be a seeded [BehaviorSubject] stream so that new
/// subscribers immediately receive the current state. [SwitchableTickService]
/// relies on this seeded-replay behaviour (mirrors the former
/// `_effectiveActive.stream` in [HeartRateTickService]).
abstract interface class ITickCadenceSource {
  /// Moving-average cadence curve. Emits milliseconds per beat whenever the
  /// underlying smoothed-RR estimate is updated.
  Stream<int> get smoothedPeriodMs;

  /// Synchronous snapshot of the latest smoothed period in milliseconds.
  /// Returns `null` before any interval has been accepted (cold path).
  ///
  /// Used by the metronome to seed its initial [_currentPeriodMs] at
  /// construction time, before the first async emission from [smoothedPeriodMs]
  /// arrives (preserves the byte-for-byte warm-path seed that existed in the
  /// previous monolithic [HeartRateTickService]).
  int? get currentPeriodMs;

  /// Whether this source can currently drive ticks reliably.
  bool get isUsable;

  /// Transitions of [isUsable]. Must be a seeded [BehaviorSubject] stream —
  /// replay of the current value to new subscribers is required.
  Stream<bool> get usableChanges;

  void dispose();
}
