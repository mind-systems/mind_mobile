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
  final String? nextCursor;
  final BreathSessionNotifierEvent? lastEvent;

  const BreathSessionsState({
    required this.entries,
    required this.nextCursor,
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

/// Domain notifier — source of truth for breathing sessions.
class BreathSessionNotifier {
  final IBreathSessionRepository repository;

  final BehaviorSubject<BreathSessionsState> _subject = BehaviorSubject.seeded(
    const BreathSessionsState(entries: [], nextCursor: null, lastEvent: null),
  );

  bool _isLoading = false;
  StreamSubscription<String>? _userSubscription;

  BreathSessionNotifier({required this.repository, required Stream<AuthState> authStream}) {
    _userSubscription = authStream
        .map((s) => s.user.id)
        .distinct()
        .skip(1)
        .listen(_onUserIdChanged);
  }

  void _onUserIdChanged(String _) async {
    await repository.deleteAll();
    invalidate();
  }

  void invalidate() {
    _subject.add(BreathSessionsState(
      entries: const [],
      nextCursor: null,
      lastEvent: SessionsInvalidated(),
    ));
  }

  Stream<BreathSessionsState> get stream => _subject.stream;

  BreathSessionsState get currentState => _subject.value;

  /// ---------- Pagination ----------

  Future<void> load(String? cursor, int pageSize) async {
    if (_isLoading) return;

    _isLoading = true;

    try {
      final result = await repository.fetch(cursor, pageSize);
      final state = _subject.value;

      final List<BreathSessionListEntry> updatedEntries;

      if (cursor == null) {
        // First page — replace entirely
        updatedEntries = result.entries;
      } else {
        // Append — no dedup
        updatedEntries = [...state.entries, ...result.entries];
      }

      _subject.add(BreathSessionsState(
        entries: updatedEntries,
        nextCursor: result.nextCursor,
        lastEvent: PageLoaded(
          entries: result.entries,
          nextCursor: result.nextCursor,
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
      final result = await repository.refresh(pageSize);

      _subject.add(BreathSessionsState(
        entries: result.entries,
        nextCursor: result.nextCursor,
        lastEvent: SessionsRefreshed(
          entries: result.entries,
          nextCursor: result.nextCursor,
        ),
      ));
    } finally {
      _isLoading = false;
    }
  }

  /// ---------- CRUD ----------

  Future<BreathSession> create(BreathSession session) async {
    final saved = await repository.create(session);
    final state = _subject.value;
    final newEntry = BreathSessionListEntry(session: saved, section: BreathListSection.mine);
    final updatedEntries = [newEntry, ...state.entries];
    _subject.add(BreathSessionsState(
      entries: updatedEntries,
      nextCursor: state.nextCursor,
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
      nextCursor: state.nextCursor,
      lastEvent: SessionUpdated(saved),
    ));
    return saved;
  }

  Future<void> starSession(String id, {required bool starred}) async {
    await repository.starSession(id, starred: starred);
    final state = _subject.value;

    // If the session is not in the entry list, skip optimistic mutation.
    // The server write has already succeeded; the next load/refresh will sync it.
    if (!state.entries.any((e) => e.session.id == id)) return;

    // Capture source before any mutation — guaranteed to exist by the guard above.
    // Used as fallback for the event payload when unstar removes the only loaded copy.
    final source = state.entries.firstWhere((e) => e.session.id == id).session;

    List<BreathSessionListEntry> updatedEntries;

    if (starred) {
      // Set isStarred=true on every entry with this id
      updatedEntries = state.entries.map((e) {
        if (e.session.id == id) {
          return BreathSessionListEntry(
            session: e.session.copyWith(isStarred: true),
            section: e.section,
          );
        }
        return e;
      }).toList();

      // If no entry with section==starred exists for this id, prepend one.
      // Safe: source exists, so firstWhere will always match.
      final hasStarredEntry = updatedEntries.any(
        (e) => e.session.id == id && e.section == BreathListSection.starred,
      );
      if (!hasStarredEntry) {
        final base = updatedEntries.firstWhere((e) => e.session.id == id);
        final starredEntry = BreathSessionListEntry(
          session: base.session.copyWith(isStarred: true),
          section: BreathListSection.starred,
        );
        updatedEntries = [starredEntry, ...updatedEntries];
      }
    } else {
      // Remove every entry where id==id && section==starred
      // Set isStarred=false on remaining entries with this id
      updatedEntries = state.entries
          .where((e) => !(e.session.id == id && e.section == BreathListSection.starred))
          .map((e) {
            if (e.session.id == id) {
              return BreathSessionListEntry(
                session: e.session.copyWith(isStarred: false),
                section: e.section,
              );
            }
            return e;
          })
          .toList();
    }

    // When unstarring a session that was only present as a STARRED entry (e.g. its MINE/SHARED
    // duplicate is on an unloaded page), updatedEntries has no entry with this id after filtering.
    // Fall back to source for the event payload — the list path ignores it anyway.
    final updatedSession = updatedEntries
        .firstWhere(
          (e) => e.session.id == id,
          orElse: () => BreathSessionListEntry(
            session: source.copyWith(isStarred: starred),
            section: BreathListSection.mine,
          ),
        )
        .session;

    _subject.add(BreathSessionsState(
      entries: updatedEntries,
      nextCursor: state.nextCursor,
      lastEvent: SessionStarred(updatedSession),
    ));
  }

  Future<void> delete(String id) async {
    await repository.delete(id);

    final state = _subject.value;
    final updatedEntries = state.entries.where((e) => e.session.id != id).toList();

    _subject.add(BreathSessionsState(
      entries: updatedEntries,
      nextCursor: state.nextCursor,
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
