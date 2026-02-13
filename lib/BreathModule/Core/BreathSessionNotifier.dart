import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'package:mind/BreathModule/Core/BreathSessionRepository.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Core/Models/BreathSessionNotifierEvent.dart';
import 'package:mind/User/UserNotifier.dart';

class BreathSessionsState {
  final Map<String, BreathSession> byId;
  final List<String> order;
  final BreathSessionNotifierEvent? lastEvent;

  const BreathSessionsState({
    required this.byId,
    required this.order,
    required this.lastEvent,
  });

  List<BreathSession> get orderedSessions =>
      order.map((id) => byId[id]!).toList();
}

/// Доменный нотифаер — источник правды по сессиям дыхания.
class BreathSessionNotifier {
  final BreathSessionRepository repository;
  final UserNotifier userNotifier;

  final BehaviorSubject<BreathSessionsState> _subject = BehaviorSubject.seeded(
    const BreathSessionsState(byId: {}, order: [], lastEvent: null),
  );

  bool _isLoading = false;
  StreamSubscription<String>? _userSubscription;

  BreathSessionNotifier({required this.repository, required this.userNotifier}) {
    _userSubscription = userNotifier.stream
        .map((s) => s.user.id)
        .distinct()
        .skip(1)
        .listen(_onUserIdChanged);
  }

  void _onUserIdChanged(String _) async {
    await repository.deleteAll();
    _subject.add(BreathSessionsState(
      byId: {},
      order: [],
      lastEvent: SessionsInvalidated(),
    ));
  }

  Stream<BreathSessionsState> get stream => _subject.stream;

  BreathSessionsState get currentState => _subject.value;

  /// ---------- Pagination ----------

  Future<void> load(int page, int pageSize) async {
    if (_isLoading) return;

    _isLoading = true;

    try {
      final sessions = await repository.fetch(page, pageSize);
      final hasMore = sessions.length >= pageSize;

      final Map<String, BreathSession> updatedById;
      final List<String> updatedOrder;
      final List<BreathSession> newSessions;

      final state = _subject.value;

      if (page == 0) {
        updatedById = {for (final s in sessions) s.id: s};
        updatedOrder = sessions.map((s) => s.id).toList();
        newSessions = sessions;
      } else {
        updatedById = Map.from(state.byId);
        updatedOrder = List.from(state.order);
        newSessions = [];

        for (final session in sessions) {
          final isNew = !state.byId.containsKey(session.id);
          updatedById[session.id] = session;
          if (isNew) {
            updatedOrder.add(session.id);
            newSessions.add(session);
          }
        }
      }

      _subject.add(BreathSessionsState(
        byId: updatedById,
        order: updatedOrder,
        lastEvent: PageLoaded(
          page: page,
          sessions: newSessions,
          hasMore: hasMore,
        ),
      ));
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refresh(int pageSize) async {
    if (_isLoading) return;

    _isLoading = true;

    try {
      final sessions = await repository.fetch(0, pageSize);
      final hasMore = sessions.length >= pageSize;

      _subject.add(BreathSessionsState(
        byId: {for (final s in sessions) s.id: s},
        order: sessions.map((s) => s.id).toList(),
        lastEvent: SessionsRefreshed(
          sessions: sessions,
          hasMore: hasMore,
        ),
      ));
    } finally {
      _isLoading = false;
    }
  }

  /// ---------- CRUD ----------

  Future<void> save(BreathSession session) async {
    await repository.save(session);

    final state = _subject.value;
    final isNew = !state.byId.containsKey(session.id);

    final updatedById = Map<String, BreathSession>.from(state.byId);
    updatedById[session.id] = session;

    final updatedOrder = List<String>.from(state.order);
    if (isNew) {
      updatedOrder.insert(0, session.id);
    }

    _subject.add(BreathSessionsState(
      byId: updatedById,
      order: updatedOrder,
      lastEvent: isNew ? SessionCreated(session) : SessionUpdated(session),
    ));
  }

  Future<void> delete(String id) async {
    await repository.delete(id);

    final state = _subject.value;
    final updatedById = Map<String, BreathSession>.from(state.byId);
    updatedById.remove(id);

    final updatedOrder = List<String>.from(state.order);
    updatedOrder.remove(id);

    _subject.add(BreathSessionsState(
      byId: updatedById,
      order: updatedOrder,
      lastEvent: SessionDeleted(id),
    ));
  }

  /// ---------- Sync access ----------

  Future<BreathSession?> getById(String id) async {
    if (_subject.value.byId.containsKey(id)) {
      return _subject.value.byId[id];
    }
    return await repository.fetchById(id);
  }

  void dispose() {
    _userSubscription?.cancel();
    _subject.close();
  }
}
