import 'package:mind/Core/Grpc/InstructionSample.dart';
import 'package:mind/Core/Grpc/ModuleInstructionStream.dart';

class BreathModuleInstructionStream {
  final ModuleInstructionStream _instructionStream;

  BreathModuleInstructionStream({required ModuleInstructionStream instructionStream})
      : _instructionStream = instructionStream;

  void sendSample(String sessionId, String phase, int durationMs, int timestampMs) {
    _instructionStream.emit(InstructionSample(
      sessionId: sessionId,
      timestamp: timestampMs,
      moduleId: 'breath',
      instructionType: 'breath_phase',
      data: {'phase': phase, 'durationMs': durationMs},
    ));
  }
}
