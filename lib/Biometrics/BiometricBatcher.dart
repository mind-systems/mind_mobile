import 'dart:async';

import 'BioSample.dart';
import 'BioStreamRouter.dart';
import 'BiometricStreamClient.dart';

/// Buffering stage between [BioStreamRouter] (sample producer) and
/// [BiometricStreamClient] (gRPC sink).
///
/// Flushes on size (25 samples) or a 250 ms deadline, whichever fires first.
/// No backpressure logic — the client owns drop/replay decisions.
///
/// Reference: `.ai-factory/notes/28-biometric-stream-pipeline.md` "Milestone 8".
class BiometricBatcher {
  static const int _maxBatchSize = 25;
  static const Duration _flushInterval = Duration(milliseconds: 250);

  final BioStreamRouter _router;
  final BiometricStreamClient _client;

  final List<BioSample> _buffer = [];
  Timer? _flushTimer;
  StreamSubscription<BioSample>? _sub;

  BiometricBatcher({
    required BioStreamRouter router,
    required BiometricStreamClient client,
  })  : _router = router,
        _client = client {
    _sub = _router.samples.listen(_onSample);
  }

  // ── Sample handling ────────────────────────────────────────────────────────

  void _onSample(BioSample sample) {
    _buffer.add(sample);
    if (_buffer.length >= _maxBatchSize) {
      _flushNow();
      return;
    }
    _flushTimer ??= Timer(_flushInterval, _flushNow);
  }

  // ── Flush ──────────────────────────────────────────────────────────────────

  void _flushNow() {
    if (_buffer.isEmpty) return;
    final snapshot = List<BioSample>.unmodifiable(_buffer);
    _buffer.clear();
    _flushTimer?.cancel();
    _flushTimer = null;
    _client.sendBatch(snapshot);
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _flushNow();
  }
}
