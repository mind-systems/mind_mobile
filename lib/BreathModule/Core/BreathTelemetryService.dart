import 'dart:async';

import 'package:breath_module/breath_module.dart' show IBreathTelemetryService;
import 'package:mind/Core/Socket/LiveSocketService.dart';
import 'package:mind/Core/Socket/TelemetryBuffer.dart';

class BreathTelemetryService implements IBreathTelemetryService {
  final LiveSocketService _liveSocketService;
  final TelemetryBuffer _buffer = TelemetryBuffer();

  int _maxSamplesPerSecond = 10;
  DateTime? _lastSendTime;

  StreamSubscription<void>? _telemetryStateSub;
  StreamSubscription<Map<String, dynamic>>? _dataAckSub;

  BreathTelemetryService({required LiveSocketService liveSocketService})
      : _liveSocketService = liveSocketService {
    _telemetryStateSub = _liveSocketService.telemetryStateEvents.listen((_) => flushBuffer());
    _dataAckSub = _liveSocketService.dataAckEvents.listen(_onDataAck);
  }

  @override
  void sendSample(String sessionId, String phase, int durationMs) {
    final payload = {
      'sessionId': sessionId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': {
        'phase': phase,
        'durationMs': durationMs,
      },
    };

    if (_canSendNow()) {
      _emit(payload);
    } else {
      _buffer.enqueue(payload);
    }
  }

  void flushBuffer() {
    for (final sample in _buffer.flush()) {
      _liveSocketService.emitTelemetry('data:stream', sample);
    }
  }

  void dispose() {
    _telemetryStateSub?.cancel();
    _dataAckSub?.cancel();
  }

  bool _canSendNow() {
    if (!_liveSocketService.isConnected) return false;
    if (_lastSendTime == null) return true;
    final minIntervalMs = 1000 ~/ _maxSamplesPerSecond;
    return DateTime.now().difference(_lastSendTime!).inMilliseconds >= minIntervalMs;
  }

  void _emit(Map<String, dynamic> payload) {
    _liveSocketService.emitTelemetry('data:stream', payload);
    _lastSendTime = DateTime.now();
  }

  void _onDataAck(Map<String, dynamic> data) {
    final rate = data['maxSamplesPerSecond'];
    if (rate is int && rate > 0) {
      _maxSamplesPerSecond = rate;
    }
  }
}
