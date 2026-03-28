class InstructionSample {
  final String sessionId;
  final int timestamp;
  final String moduleId;
  final String instructionType;
  final Map<String, dynamic> data;

  const InstructionSample({
    required this.sessionId,
    required this.timestamp,
    required this.moduleId,
    required this.instructionType,
    required this.data,
  });
}
