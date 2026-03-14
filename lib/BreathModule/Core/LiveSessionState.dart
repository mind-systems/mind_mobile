enum LiveSessionStatus { idle, active }

class LiveSessionState {
  final String? liveSessionId;
  final LiveSessionStatus status;

  const LiveSessionState({required this.liveSessionId, required this.status});

  factory LiveSessionState.initial() =>
      const LiveSessionState(liveSessionId: null, status: LiveSessionStatus.idle);
}
