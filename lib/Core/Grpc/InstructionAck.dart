class InstructionAck {
  final String sessionId;
  final int receivedCount;
  final int droppedCount;
  final int maxSamplesPerSecond;
  final int timestamp;

  const InstructionAck({
    required this.sessionId,
    required this.receivedCount,
    required this.droppedCount,
    required this.maxSamplesPerSecond,
    required this.timestamp,
  });
}
