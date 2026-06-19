import 'dart:async';

import 'package:breath_module/breath_module.dart' show ITickService, TickData, TickSource;
import 'package:mind/Biometrics/ActiveRrSource.dart';

class HeartRateTickService implements ITickService {
  HeartRateTickService({required ActiveRrSource activeRrSource})
      : _activeRrSource = activeRrSource {
    _sub = _activeRrSource.stream.listen((rr) {
      _tickController.add(TickData(rr.intervalMs));
    });
  }

  final ActiveRrSource _activeRrSource;
  final StreamController<TickData> _tickController = StreamController<TickData>.broadcast();
  StreamSubscription? _sub;

  @override
  Stream<TickData> get tickStream => _tickController.stream;

  @override
  TickSource get source => TickSource.heartbeat;

  /// Placeholder until the first measured RR interval arrives.
  /// The service caches no last RR and has no BPM target, so 1000 ms is the
  /// honest default before the first beat; the origin seed is overwritten on
  /// the first real RR tick.
  @override
  int get nominalIntervalMs => 1000;

  /// Proxy for callers that need to gate UI on source availability.
  bool get hasActiveSource => _activeRrSource.hasActiveSource;

  /// Transitions of [hasActiveSource]. Consumed by [SwitchableTickService] for
  /// auto-fallback when all RR sources go silent.
  Stream<bool> get hasActiveSourceStream => _activeRrSource.hasActiveSourceStream;

  @override
  Stream<TickSource> get sourceChanges => const Stream.empty();

  @override
  bool trySwitchTo(TickSource target) => false;

  @override
  void dispose() {
    _sub?.cancel();
    _tickController.close();
    // Do NOT dispose _activeRrSource — owned by App, shared with future consumers.
  }
}
