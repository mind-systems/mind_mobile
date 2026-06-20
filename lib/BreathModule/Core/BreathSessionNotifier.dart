import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'package:mind/BreathModule/Core/IBreathSessionRepository.dart';
import 'package:mind/BreathModule/Models/BreathListSection.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/BreathSessionsListResponse.dart';
import 'package:mind/BreathModule/Core/Models/BreathSessionNotifierEvent.dart';
import 'package:mind/User/Models/AuthState.dart';

class BreathSessionsState {
  final List<BreathSessionListEntry> entries;
  final BreathSessionNotifierEvent? lastEvent;

  const BreathSessionsState({
    required this.entries,
    required this.lastEvent,
  });

  /// Synchronous lookup for non-list consumers.
  /// Returns the first entry matching [id], or null if not found.
  BreathSession? cachedById(String id) {
    for (final entry in entries) {
      if (entry.session.id == id) return entry.session;
    }
    return null;
  }
}

/// Derives sectioned entries from a flat session list.
/// Emits one ownership entry (MINE or SHARED) per session, plus a STARRED
/// duplicate for every starred session.
/// Sorts by [createdAt] DESC with a deterministic secondary tie-breaker on [id].
List<BreathSessionListEntry> buildSectionedEntries(
    List<BreathSession> sessions, String currentUserId) {
  final sorted = List<BreathSession>.of(sessions)
    ..sort((a, b) {
      final c = b.createdAt.compareTo(a.createdAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });

  final entries = <BreathSessionListEntry>[];
  for (final session in sorted) {
    final ownershipSection =
        session.userId == currentUserId ? BreathListSection.mine : BreathListSection.shared;
    entries.add(BreathSessionListEntry(session: session, section: ownershipSection));
    if (session.isStarred) {
      entries.add(BreathSessionListEntry(session: session, section: BreathListSection.starred));
    }
  }
  return entries;
}

/// De-duplicates entries by session id.
/// When the same id appears more than once, the surviving session has
/// [isStarred] = true if **any** duplicate carries it (OR logic).
/// All other fields come from the first occurrence.
List<BreathSession> _uniqueSessions(List<BreathSessionListEntry> entries) {
  final seen = <String, BreathSession>{};
  for (final entry in entries) {
    final s = entry.session;
    final existing = seen[s.id];
    if (existing == null) {
      seen[s.id] = s;
    } else if (s.isStarred && !existing.isStarred) {
      seen[s.id] = existing.copyWith(isStarred: true);
    }
  }
  return seen.values.toList();
}

/// Domain notifier — source of truth for breathing sessions.
class BreathSessionNotifier {
  final IBreathSessionRepository repository;
  final String Function() currentUserId;

  final BehaviorSubject<BreathSessionsState> _subject = BehaviorSubject.seeded(
    const BreathSessionsState(entries: [], lastEvent: null),
  );

  bool _isLoading = false;
  StreamSubscription<String>? _userSubscription;

  BreathSessionNotifier({
    required this.repository,
    required Stream<AuthState> authStream,
    required this.currentUserId,
  }) {
    _userSubscription = authStream
        .map((s) => s.user.id)
        .distinct()
        .skip(1)
        .listen(_onUserIdChanged);
  }

  void _onUserIdChanged(String _) async {
    await repository.deleteAll();
    await invalidate();
  }

  Future<List<BreathSessionListEntry>> _readLocalEntries() async {
    final sessions = await repository.localSessions();
    return buildSectionedEntries(sessions, currentUserId());
  }

  Future<void> loadLocal() async {
    final entries = await _readLocalEntries();
    if (entries.isEmpty) return;
    _subject.add(BreathSessionsState(
      entries: entries,
      lastEvent: LocalSessionsLoaded(),
    ));
  }

  Future<void> invalidate() async {
    final entries = await _readLocalEntries();
    _subject.add(BreathSessionsState(
      entries: entries,
      lastEvent: LocalSessionsLoaded(),
    ));
  }

  Stream<BreathSessionsState> get stream => _subject.stream;

  BreathSessionsState get currentState => _subject.value;

  /// ---------- Refresh ----------

  /// Write-through full-mirror sync: loops all pages from the server into Drift,
  /// then re-reads Drift and emits the complete local mirror.
  /// On network failure, rethrows without touching the current state.
  Future<void> refresh(int pageSize) async {
    if (_isLoading) return;

    _isLoading = true;

    try {
      await repository.refresh(pageSize);
      final updatedEntries = await _readLocalEntries();

      _subject.add(BreathSessionsState(
        entries: updatedEntries,
        lastEvent: SessionsRefreshed(),
      ));
    } finally {
      _isLoading = false;
    }
  }

  /// ---------- CRUD ----------

  Future<BreathSession> create(BreathSession session) async {
    final saved = await repository.create(session);
    final state = _subject.value;
    final sessions = _uniqueSessions([
      BreathSessionListEntry(session: saved, section: BreathListSection.mine),
      ...state.entries,
    ]);
    final updatedEntries = buildSectionedEntries(sessions, currentUserId());
    _subject.add(BreathSessionsState(
      entries: updatedEntries,
      lastEvent: SessionCreated(saved),
    ));
    return saved;
  }

  Future<BreathSession> update(BreathSession session) async {
    final saved = await repository.update(session);
    final state = _subject.value;
    // Replace session on every entry whose id matches, preserving each entry's section
    final updatedEntries = state.entries.map((e) {
      if (e.session.id == saved.id) {
        return BreathSessionListEntry(session: saved, section: e.section);
      }
      return e;
    }).toList();
    _subject.add(BreathSessionsState(
      entries: updatedEntries,
      lastEvent: SessionUpdated(saved),
    ));
    return saved;
  }

  Future<void> starSession(String id, {required bool starred}) async {
    await repository.starSession(id, starred: starred);
    final state = _subject.value;

    // If the session is not in the entry list, skip optimistic mutation.
    // The server write has already succeeded; the next refresh will sync it.
    if (!state.entries.any((e) => e.session.id == id)) return;

    final sessions = _uniqueSessions(state.entries)
        .map((s) => s.id == id ? s.copyWith(isStarred: starred) : s)
        .toList();

    final updatedEntries = buildSectionedEntries(sessions, currentUserId());

    final updatedSession = sessions.firstWhere((s) => s.id == id);

    _subject.add(BreathSessionsState(
      entries: updatedEntries,
      lastEvent: SessionStarred(updatedSession),
    ));
  }

  Future<void> delete(String id) async {
    await repository.delete(id);

    final state = _subject.value;
    final updatedEntries = state.entries.where((e) => e.session.id != id).toList();

    _subject.add(BreathSessionsState(
      entries: updatedEntries,
      lastEvent: SessionDeleted(id),
    ));
  }

  /// ---------- Sync access ----------

  Future<BreathSession?> getById(String id) async {
    final cached = currentState.cachedById(id);
    if (cached != null) return cached;
    return await repository.fetchById(id);
  }

  void dispose() {
    _userSubscription?.cancel();
    _subject.close();
  }
}
