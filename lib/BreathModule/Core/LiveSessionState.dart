enum LiveSessionStatus { idle, active }

class LiveSessionState {
  final String? liveSessionId;
  final LiveSessionStatus status;
  final bool isPaused;

  const LiveSessionState({required this.liveSessionId, required this.status, this.isPaused = false});

  factory LiveSessionState.initial() =>
      const LiveSessionState(liveSessionId: null, status: LiveSessionStatus.idle);
}
