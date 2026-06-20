import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/BreathSessionsListResponse.dart';

sealed class BreathSessionNotifierEvent {}

class PageLoaded extends BreathSessionNotifierEvent {
  final List<BreathSessionListEntry> entries;
  final String? nextCursor;

  PageLoaded({
    required this.entries,
    required this.nextCursor,
  });
}

class SessionsRefreshed extends BreathSessionNotifierEvent {
  final List<BreathSessionListEntry> entries;
  final String? nextCursor;

  SessionsRefreshed({
    required this.entries,
    required this.nextCursor,
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

class SessionsInvalidated extends BreathSessionNotifierEvent {}

class LocalSessionsLoaded extends BreathSessionNotifierEvent {}

class SessionStarred extends BreathSessionNotifierEvent {
  final BreathSession session;

  SessionStarred(this.session);
}
