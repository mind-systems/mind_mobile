import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/BreathModule/Core/BreathSessionRepository.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Core/Models/BreathSessionNotifierEvent.dart';

class BreathSessionsState {
  final List<BreathSession> cachedSessions;
  final BreathSessionNotifierEvent? lastEvent;

  const BreathSessionsState({
    required this.cachedSessions,
    required this.lastEvent,
  });

  BreathSessionsState copyWith({
    List<BreathSession>? cachedSessions,
    BreathSessionNotifierEvent? lastEvent,
  }) {
    return BreathSessionsState(
      cachedSessions: cachedSessions ?? this.cachedSessions,
      lastEvent: lastEvent,
    );
  }
}

class BreathSessionNotifier extends Notifier<BreathSessionsState> {
  final BreathSessionRepository repository;

  final StreamController<BreathSessionsState> _controller =
  StreamController<BreathSessionsState>.broadcast();

  BreathSessionNotifier({required this.repository});

  Stream<BreathSessionsState> get stream => _controller.stream;

  @override
  BreathSessionsState build() {
    ref.onDispose(() {
      _controller.close();
    });

    return const BreathSessionsState(
      cachedSessions: [],
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
    final sessions = await repository.fetch(page, pageSize);
    final hasMore = sessions.length >= pageSize;

    final updatedCache = page == 0
        ? sessions
        : [...state.cachedSessions, ...sessions];

    state = state.copyWith(
      cachedSessions: updatedCache,
      lastEvent: PageLoaded(
        page: page,
        sessions: sessions,
        hasMore: hasMore,
      ),
    );
  }

  Future<void> refresh(int pageSize) async {
    final sessions = await repository.fetch(0, pageSize);
    final hasMore = sessions.length >= pageSize;

    state = state.copyWith(
      cachedSessions: sessions,
      lastEvent: SessionsRefreshed(
        sessions: sessions,
        hasMore: hasMore,
      ),
    );
  }

  /// ---------- CRUD ----------

  Future<void> save(BreathSession session) async {
    await repository.save(session);

    final index =
    state.cachedSessions.indexWhere((s) => s.id == session.id);

    if (index == -1) {
      final updatedCache = [...state.cachedSessions, session];

      state = state.copyWith(
        cachedSessions: updatedCache,
        lastEvent: SessionCreated(session),
      );
    } else {
      final updatedCache = [
        for (final s in state.cachedSessions)
          if (s.id == session.id) session else s,
      ];

      state = state.copyWith(
        cachedSessions: updatedCache,
        lastEvent: SessionUpdated(session),
      );
    }
  }

  Future<void> delete(String id) async {
    await repository.delete(id);

    final updatedCache =
    state.cachedSessions.where((s) => s.id != id).toList();

    state = state.copyWith(
      cachedSessions: updatedCache,
      lastEvent: SessionDeleted(id),
    );
  }

  /// ---------- Sync access ----------

  BreathSession? getById(String id) {
    for (final session in state.cachedSessions) {
      if (session.id == id) return session;
    }
    return null;
  }
}

final breathSessionNotifierProvider =
    NotifierProvider<BreathSessionNotifier, BreathSessionsState>(() {
  throw UnimplementedError(
    'BreathSessionNotifier должен быть передан в ProviderScope',
  );
});