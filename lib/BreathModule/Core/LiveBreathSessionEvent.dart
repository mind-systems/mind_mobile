sealed class LiveBreathSessionEvent {}

class LiveBreathSessionStarted extends LiveBreathSessionEvent {
  final String? liveSessionId;
  LiveBreathSessionStarted({this.liveSessionId});
}

class LiveBreathSessionEnded extends LiveBreathSessionEvent {}

class LiveBreathSessionAbandoned extends LiveBreathSessionEvent {}

class LiveBreathSessionPaused extends LiveBreathSessionEvent {}

class LiveBreathSessionUnpaused extends LiveBreathSessionEvent {}
