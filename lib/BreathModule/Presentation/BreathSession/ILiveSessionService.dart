class LiveSessionDto {
  final String? liveSessionId;
  final bool isActive;

  const LiveSessionDto({required this.liveSessionId, required this.isActive});
}

abstract class ILiveSessionService {
  void startSession(String sessionId);
  void endSession();
  Stream<LiveSessionDto> get sessionStateStream;
}
