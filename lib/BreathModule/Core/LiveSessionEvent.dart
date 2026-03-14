sealed class LiveSessionEvent {}

class LiveSessionStarted extends LiveSessionEvent {
  final String? liveSessionId;
  LiveSessionStarted({this.liveSessionId});
}

class LiveSessionEnded extends LiveSessionEvent {}

class LiveSessionAbandoned extends LiveSessionEvent {}
