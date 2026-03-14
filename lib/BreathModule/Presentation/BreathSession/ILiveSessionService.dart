class LiveSessionDto {
  final String? liveSessionId;
  final bool isActive;
  final bool isPaused;

  const LiveSessionDto({required this.liveSessionId, required this.isActive, this.isPaused = false});
}

abstract class ILiveSessionService {
  void startSession(String sessionId);
  void endSession();
  void pauseSession();
  void resumeSession();
  Stream<LiveSessionDto> get sessionStateStream;
}
