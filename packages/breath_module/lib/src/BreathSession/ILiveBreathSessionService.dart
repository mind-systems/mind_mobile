class LiveBreathSessionDto {
  final String? liveSessionId;
  final bool isActive;
  final bool isPaused;

  const LiveBreathSessionDto({required this.liveSessionId, required this.isActive, this.isPaused = false});
}

abstract class ILiveBreathSessionService {
  void startSession(String sessionId);
  void endSession();
  void pauseSession();
  void resumeSession();
  Stream<LiveBreathSessionDto> get sessionStateStream;
}
