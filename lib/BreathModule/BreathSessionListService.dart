import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/BreathModule/Core/Models/BreathSessionNotifierEvent.dart';
import 'package:mind/BreathModule/Models/BreathListSection.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/BreathSessionsListResponse.dart';
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
      if (event == null) return const [];
      if (event is SessionsInvalidated) {
        return [SessionsInvalidatedEvent()];
      }
      // All other events → emit full-list snapshot
      return [
        ListUpdatedEvent(
          items: _mapEntries(state.entries),
          hasMore: state.nextCursor != null && state.nextCursor!.isNotEmpty,
        )
      ];
    });
  }

  /// ---------- Pagination ----------

  @override
  Future<void> loadNext(int pageSize) async {
    await notifier.load(notifier.currentState.nextCursor, pageSize);
  }

  @override
  Future<void> refresh(int pageSize) async {
    await notifier.refresh(pageSize);
  }

  /// ---------- Mapping ----------

  List<BreathSessionListItemDTO> _mapEntries(List<BreathSessionListEntry> entries) {
    return entries.map(_mapEntry).toList();
  }

  BreathSessionListItemDTO _mapEntry(BreathSessionListEntry entry) {
    return _mapSession(entry.session, section: _mapSection(entry.section));
  }

  BreathSessionListItemDTO _mapSession(BreathSession session, {required ListSection section}) {
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
      section: section,
    );
  }

  ListSection _mapSection(BreathListSection section) {
    switch (section) {
      case BreathListSection.starred:
        return ListSection.starred;
      case BreathListSection.mine:
        return ListSection.mine;
      case BreathListSection.shared:
        return ListSection.shared;
    }
  }

  BreathPatternDTO _exerciseSetToPattern(ExerciseSet exerciseSet) {
    final isRestOnly = exerciseSet.steps.isEmpty;
    final durations = exerciseSet.steps.map((step) => step.duration).toList();

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
    if (session.userId == currentUser.id) {
      return SessionOwnership.mine;
    }
    return SessionOwnership.shared;
  }
}
