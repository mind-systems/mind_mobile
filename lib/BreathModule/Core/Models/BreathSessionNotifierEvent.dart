import 'package:mind/BreathModule/Models/BreathSession.dart';

sealed class BreathSessionNotifierEvent {}

class PageLoaded extends BreathSessionNotifierEvent {
  final int page;
  final List<BreathSession> sessions;
  final bool hasMore;

  PageLoaded({
    required this.page,
    required this.sessions,
    required this.hasMore,
  });
}

class SessionsRefreshed extends BreathSessionNotifierEvent {
  final List<BreathSession> sessions;
  final bool hasMore;

  SessionsRefreshed({
    required this.sessions,
    required this.hasMore,
  });
}

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
