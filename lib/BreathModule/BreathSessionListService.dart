import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/BreathModule/Core/Models/BreathSessionNotifierEvent.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:breath_module/breath_module.dart' hide SetShape;
import 'package:mind/User/UserNotifier.dart';

class BreathSessionListService implements IBreathSessionListService {
  final BreathSessionNotifier notifier;
  final UserNotifier userNotifier;

  BreathSessionListService({required this.notifier, required this.userNotifier});

  @override
  Stream<BreathSessionListEvent> observeChanges() {
    return notifier.stream.expand((state) {
      final event = state.lastEvent;
      if (event == null) return [];
      return [_mapEvent(event)];
    });
  }

  /// ---------- Pagination ----------

  @override
  Future<void> fetchPage(int page, int pageSize) async {
    await notifier.load(page, pageSize);
  }

  @override
  Future<void> refresh(int pageSize) async {
    await notifier.refresh(pageSize);
  }

  /// ---------- Notifier → Service ----------

  BreathSessionListEvent _mapEvent(BreathSessionNotifierEvent event) {
    switch (event) {
      case PageLoaded e:
        return PageLoadedEvent(
          page: e.page,
          items: _mapSessions(e.sessions),
          hasMore: e.hasMore,
        );

      case SessionsRefreshed e:
        return SessionsRefreshedEvent(
          items: _mapSessions(e.sessions),
          hasMore: e.hasMore,
        );

      case SessionCreated e:
        return SessionCreatedEvent(_mapSession(e.session));

      case SessionUpdated e:
        return SessionUpdatedEvent(_mapSession(e.session));

      case SessionDeleted e:
        return SessionDeletedEvent(e.id);

      case SessionsInvalidated _:
        return SessionsInvalidatedEvent();

      case SessionStarred e:
        return SessionUpdatedEvent(_mapSession(e.session));
    }
  }

  /// ---------- Mapping ----------

  List<BreathSessionListItemDTO> _mapSessions(
    List<BreathSession> sessions,
  ) {
    return sessions.map(_mapSession).toList();
  }

  BreathSessionListItemDTO _mapSession(BreathSession session) {
    final patterns = session.exercises.map(_exerciseSetToPattern).toList();
    final totalDuration = _calculateTotalDuration(session.exercises);
    final ownership = _determineOwnership(session);

    return BreathSessionListItemDTO(
      id: session.id,
      description: session.description,
      patterns: patterns,
      totalDurationSeconds: totalDuration,
      complexity: session.complexity,
      ownership: ownership,
      isStarred: session.isStarred,
    );
  }

  BreathPatternDTO _exerciseSetToPattern(ExerciseSet exerciseSet) {
    final isRestOnly = exerciseSet.steps.isEmpty;
    final durations =
        exerciseSet.steps.map((step) => step.duration).toList();

    return BreathPatternDTO(
      shape: _mapShape(exerciseSet.shape),
      durations: durations,
      repeatCount: exerciseSet.repeatCount,
      isRestOnly: isRestOnly,
    );
  }

  BreathPatternShape _mapShape(SetShape? shape) {
    switch (shape) {
      case SetShape.circle:
        return BreathPatternShape.circle;
      case SetShape.square:
        return BreathPatternShape.square;
      case SetShape.triangleUp:
        return BreathPatternShape.triangleUp;
      case SetShape.triangleDown:
        return BreathPatternShape.triangleDown;
      case null:
        return BreathPatternShape.circle;
    }
  }

  int _calculateTotalDuration(List<ExerciseSet> exercises) {
    return exercises.fold(
      0,
      (total, exercise) => total + exercise.totalDuration,
    );
  }

  SessionOwnership _determineOwnership(BreathSession session) {
    final currentUser = userNotifier.currentUser;

    // Если текущий пользователь — владелец сессии
    if (session.userId == currentUser.id) {
      return SessionOwnership.mine;
    }

    // Иначе это публичная сессия другого пользователя
    return SessionOwnership.shared;
  }

}
