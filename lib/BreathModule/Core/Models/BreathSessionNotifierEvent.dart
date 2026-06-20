import 'package:mind/BreathModule/Models/BreathSession.dart';

sealed class BreathSessionNotifierEvent {}

class SessionsRefreshed extends BreathSessionNotifierEvent {}

class SessionCreated extends BreathSessionNotifierEvent {
  final BreathSession session;

  SessionCreated(this.session);
}

class SessionUpdated extends BreathSessionNotifierEvent {
  final BreathSession session;

  SessionUpdated(this.session);
}

class SessionDeleted extends BreathSessionNotifierEvent {
  final String id;

  SessionDeleted(this.id);
}

class SessionsInvalidated extends BreathSessionNotifierEvent {}

class LocalSessionsLoaded extends BreathSessionNotifierEvent {}

class SessionStarred extends BreathSessionNotifierEvent {
  final BreathSession session;

  SessionStarred(this.session);
}
