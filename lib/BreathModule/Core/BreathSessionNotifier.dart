import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/Core/BreathSessionRepository.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Core/Models/BreathSessionNotifierEvent.dart';

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

class BreathSessionNotifier extends Notifier<BreathSessionsState> {
  final BreathSessionRepository repository;

  final StreamController<BreathSessionsState> _controller =
  StreamController<BreathSessionsState>.broadcast();

  bool _isLoading = false;

  BreathSessionNotifier({required this.repository});

  Stream<BreathSessionsState> get stream => _controller.stream;

  @override
  BreathSessionsState build() {
    ref.onDispose(() {
      _controller.close();
    });

    return const BreathSessionsState(
      byId: {},
      order: [],
      lastEvent: null,
    );
  }

  @override
  set state(BreathSessionsState value) {
    super.state = value;
    _controller.add(value);
  }

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

      state = BreathSessionsState(
        byId: updatedById,
        order: updatedOrder,
        lastEvent: PageLoaded(
          page: page,
          sessions: newSessions,
          hasMore: hasMore,
        ),
      );
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

      state = BreathSessionsState(
        byId: {for (final s in sessions) s.id: s},
        order: sessions.map((s) => s.id).toList(),
        lastEvent: SessionsRefreshed(
          sessions: sessions,
          hasMore: hasMore,
        ),
      );
    } finally {
      _isLoading = false;
    }
  }

  /// ---------- CRUD ----------

  Future<void> save(BreathSession session) async {
    await repository.save(session);

    final isNew = !state.byId.containsKey(session.id);

    final updatedById = Map<String, BreathSession>.from(state.byId);
    updatedById[session.id] = session;

    final updatedOrder = List<String>.from(state.order);
    if (isNew) {
      updatedOrder.insert(0, session.id);
    }

    state = BreathSessionsState(
      byId: updatedById,
      order: updatedOrder,
      lastEvent: isNew ? SessionCreated(session) : SessionUpdated(session),
    );
  }

  Future<void> delete(String id) async {
    await repository.delete(id);

    final updatedById = Map<String, BreathSession>.from(state.byId);
    updatedById.remove(id);

    final updatedOrder = List<String>.from(state.order);
    updatedOrder.remove(id);

    state = BreathSessionsState(
      byId: updatedById,
      order: updatedOrder,
      lastEvent: SessionDeleted(id),
    );
  }

  /// ---------- Sync access ----------

  BreathSession? getById(String id) {
    return state.byId[id];
  }
}

final breathSessionNotifierProvider =
    NotifierProvider<BreathSessionNotifier, BreathSessionsState>(() {
  throw UnimplementedError(
    'BreathSessionNotifier должен быть передан в ProviderScope',
  );
});
