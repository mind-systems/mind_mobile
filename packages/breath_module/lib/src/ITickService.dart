import 'CommonModels/TickSource.dart';

abstract class ITickService {
  Stream<TickData> get tickStream;
  TickSource get source;

  /// The nominal/configured cadence of this tick source, in milliseconds.
  /// This is the origin interval known at construction — not a per-tick measured
  /// delta. Use [TickData.intervalMs] for measured deltas.
  int get nominalIntervalMs;

  /// Emits each time the active tick source changes.
  Stream<TickSource> get sourceChanges;

  /// Attempts to switch the active tick source to [target].
  /// Returns `true` if the switch was performed or [target] is already active.
  /// Returns `false` if the switch cannot be performed (e.g. no heartbeat source available).
  bool trySwitchTo(TickSource target);

  void dispose();
}

class TickData {
  final int intervalMs;

  TickData(this.intervalMs);
}
