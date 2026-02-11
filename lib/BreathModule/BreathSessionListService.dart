import 'dart:async';

import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/BreathModule/Core/Models/BreathSessionNotifierEvent.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/ExerciseSet.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/IBreathSessionListService.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListItem.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListItemDTO.dart';
import 'package:mind/User/UserNotifier.dart';

class BreathSessionListService implements IBreathSessionListService {
  final BreathSessionNotifier notifier;
  final UserNotifier userNotifier;

  final StreamController<BreathSessionListEvent> _controller =
      StreamController<BreathSessionListEvent>.broadcast();

  late final StreamSubscription _subscription;

  BreathSessionListService({required this.notifier, required this.userNotifier}) {
    _subscription = notifier.stream.listen(_onNotifierState);
  }

  @override
  Stream<BreathSessionListEvent> observeChanges() => _controller.stream;

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

  void _onNotifierState(BreathSessionsState state) {
    final event = state.lastEvent;
    if (event == null) return;

    switch (event) {
      case PageLoaded e:
        _controller.add(
          PageLoadedEvent(
            page: e.page,
            items: _mapSessions(e.sessions),
            hasMore: e.hasMore,
          ),
        );
        break;

      case SessionsRefreshed e:
        _controller.add(
          SessionsRefreshedEvent(
            items: _mapSessions(e.sessions),
            hasMore: e.hasMore,
          ),
        );
        break;

      case SessionCreated e:
        _controller.add(
          SessionCreatedEvent(_mapSession(e.session)),
        );
        break;

      case SessionUpdated e:
        _controller.add(
          SessionUpdatedEvent(_mapSession(e.session)),
        );
        break;

      case SessionDeleted e:
        _controller.add(
          SessionDeletedEvent(e.id),
        );
        break;
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
      ownership: ownership,
    );
  }

  BreathPatternDTO _exerciseSetToPattern(ExerciseSet exerciseSet) {
    final durations =
        exerciseSet.steps.map((step) => step.duration).toList();

    return BreathPatternDTO(
      shape: _mapShape(exerciseSet.shape),
      durations: durations,
      repeatCount: exerciseSet.repeatCount,
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

  /// ---------- Lifecycle ----------

  void dispose() {
    _subscription.cancel();
    _controller.close();
  }
}
