import 'dart:async';

import 'package:breath_module/breath_module.dart' show IBreathTelemetryService;
import 'package:mind/Core/Grpc/InstructionAck.dart';
import 'package:mind/Core/Grpc/InstructionBuffer.dart';
import 'package:mind/Core/Grpc/InstructionSample.dart';
import 'package:mind/Core/Grpc/ModuleInstructionStream.dart';

class BreathTelemetryService implements IBreathTelemetryService {
  final ModuleInstructionStream _instructionStream;
  final InstructionBuffer _buffer = InstructionBuffer();

  int _maxSamplesPerSecond = 10;
  DateTime? _lastSendTime;

  StreamSubscription<void>? _telemetryStateSub;
  StreamSubscription<InstructionAck>? _dataAckSub;

  BreathTelemetryService({required ModuleInstructionStream instructionStream})
      : _instructionStream = instructionStream {
    _telemetryStateSub = _instructionStream.readyEvents.listen((_) => flushBuffer());
    _dataAckSub = _instructionStream.acks.listen(_onDataAck);
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
      _instructionStream.emit(InstructionSample(
        sessionId: sample['sessionId'] as String,
        timestamp: sample['timestamp'] as int,
        moduleId: sample['module_id'] as String,
        instructionType: sample['instruction_type'] as String,
        data: sample['data'] as Map<String, dynamic>,
      ));
    }
  }

  void dispose() {
    _telemetryStateSub?.cancel();
    _dataAckSub?.cancel();
  }

  bool _canSendNow() {
    if (!_instructionStream.isGrpcConnected) return false;
    if (_lastSendTime == null) return true;
    final minIntervalMs = 1000 ~/ _maxSamplesPerSecond;
    return DateTime.now().difference(_lastSendTime!).inMilliseconds >= minIntervalMs;
  }

  void _emit(Map<String, dynamic> payload) {
    _instructionStream.emit(InstructionSample(
      sessionId: payload['sessionId'] as String,
      timestamp: payload['timestamp'] as int,
      moduleId: payload['module_id'] as String,
      instructionType: payload['instruction_type'] as String,
      data: payload['data'] as Map<String, dynamic>,
    ));
    _lastSendTime = DateTime.now();
  }

  void _onDataAck(InstructionAck ack) {
    if (ack.maxSamplesPerSecond > 0) {
      _maxSamplesPerSecond = ack.maxSamplesPerSecond;
    }
  }
}
