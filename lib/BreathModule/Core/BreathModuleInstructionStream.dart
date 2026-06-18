import 'dart:async';

import 'package:mind/Core/Grpc/InstructionAck.dart';
import 'package:mind/Core/Grpc/InstructionBuffer.dart';
import 'package:mind/Core/Grpc/InstructionSample.dart';
import 'package:mind/Core/Grpc/ModuleInstructionStream.dart';

class BreathModuleInstructionStream {
  final ModuleInstructionStream _instructionStream;
  final InstructionBuffer _buffer = InstructionBuffer();

  int _maxSamplesPerSecond = 10;
  DateTime? _lastSendTime;

  StreamSubscription<InstructionAck>? _dataAckSub;

  BreathModuleInstructionStream({required ModuleInstructionStream instructionStream})
      : _instructionStream = instructionStream {
    _instructionStream.setReadyDrainHook(flushBuffer);
    _dataAckSub = _instructionStream.acks.listen(_onDataAck);
  }

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
    final items = _buffer.flush();
    for (final sample in items) {
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
