import 'dart:async';

import 'package:breath_module/breath_module.dart' show IBreathTelemetryService;
import 'package:mind/Core/Grpc/LiveSessionGrpcService.dart';
import 'package:mind/Core/Grpc/TelemetryBuffer.dart';

class BreathTelemetryService implements IBreathTelemetryService {
  final LiveSessionGrpcService _liveSessionService;
  final TelemetryBuffer _buffer = TelemetryBuffer();

  int _maxSamplesPerSecond = 10;
  DateTime? _lastSendTime;

  StreamSubscription<void>? _telemetryStateSub;
  StreamSubscription<Map<String, dynamic>>? _dataAckSub;

  BreathTelemetryService({required LiveSessionGrpcService liveSessionService})
      : _liveSessionService = liveSessionService {
    _telemetryStateSub = _liveSessionService.telemetryStateEvents.listen((_) => flushBuffer());
    _dataAckSub = _liveSessionService.dataAckEvents.listen(_onDataAck);
  }

  @override
  void sendSample(String sessionId, String phase, int durationMs) {
    final payload = {
      'sessionId': sessionId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'module_id': 'breath',
      'instruction_type': 'breath_phase',
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
      _liveSessionService.emitTelemetry('data:stream', sample);
    }
  }

  void dispose() {
    _telemetryStateSub?.cancel();
    _dataAckSub?.cancel();
  }

  bool _canSendNow() {
    if (!_liveSessionService.isConnected) return false;
    if (_lastSendTime == null) return true;
    final minIntervalMs = 1000 ~/ _maxSamplesPerSecond;
    return DateTime.now().difference(_lastSendTime!).inMilliseconds >= minIntervalMs;
  }

  void _emit(Map<String, dynamic> payload) {
    _liveSessionService.emitTelemetry('data:stream', payload);
    _lastSendTime = DateTime.now();
  }

  void _onDataAck(Map<String, dynamic> data) {
    final rate = data['maxSamplesPerSecond'];
    if (rate is int && rate > 0) {
      _maxSamplesPerSecond = rate;
    }
  }
}
