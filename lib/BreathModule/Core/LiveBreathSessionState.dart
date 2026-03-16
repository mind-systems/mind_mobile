enum LiveBreathSessionStatus { idle, active }

class LiveBreathSessionState {
  final String? liveSessionId;
  final LiveBreathSessionStatus status;
  final bool isPaused;

  const LiveBreathSessionState({required this.liveSessionId, required this.status, this.isPaused = false});

  factory LiveBreathSessionState.initial() =>
      const LiveBreathSessionState(liveSessionId: null, status: LiveBreathSessionStatus.idle);
}
