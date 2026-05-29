import 'CommonModels/TickSource.dart';

abstract class ITickService {
  Stream<TickData> get tickStream;
  TickSource get source;

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
