import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';

import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/BreathModule/Core/IBreathSessionRepository.dart';
import 'package:mind/BreathModule/Core/Models/BreathSessionNotifierEvent.dart';
import 'package:mind/BreathModule/Models/BreathListSection.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/BreathSessionsListResponse.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Models/User.dart';

// ---------------------------------------------------------------------------
// Fake repository
// ---------------------------------------------------------------------------

class FakeBreathSessionRepository implements IBreathSessionRepository {
  List<BreathSession> _sessions = [];
  int deleteAllCount = 0;
  /// Controls the section tag returned by fetch/refresh. Tests that need
  /// starred-only entries can set this to BreathListSection.starred.
  BreathListSection sectionForFetch = BreathListSection.mine;

  void seed(List<BreathSession> sessions) => _sessions = List.of(sessions);

  @override
  Future<BreathSession> fetchById(String id) async =>
      _sessions.firstWhere((s) => s.id == id);

  /// Cursor is encoded as 'offset:N' for simple simulation.
  /// null cursor = first page (offset 0).
  @override
  Future<({List<BreathSessionListEntry> entries, String? nextCursor})> fetch(
      String? cursor, int pageSize) async {
    final offset = cursor != null ? int.parse(cursor.split(':')[1]) : 0;
    final slice = _sessions.skip(offset).take(pageSize).toList();
    final nextOffset = offset + slice.length;
    final nextCursor = nextOffset < _sessions.length ? 'offset:$nextOffset' : null;
    final entries = slice
        .map((s) => BreathSessionListEntry(session: s, section: sectionForFetch))
        .toList();
    return (entries: entries, nextCursor: nextCursor);
  }

  @override
  Future<({List<BreathSessionListEntry> entries, String? nextCursor})> refresh(
      int pageSize) async {
    final slice = _sessions.take(pageSize).toList();
    final nextCursor = slice.length < _sessions.length ? 'offset:${slice.length}' : null;
    final entries = slice
        .map((s) => BreathSessionListEntry(session: s, section: sectionForFetch))
        .toList();
    return (entries: entries, nextCursor: nextCursor);
  }

  @override
  Future<BreathSession> create(BreathSession session) async {
    final saved = session.copyWith(id: 'saved-${session.id}');
    _sessions = [saved, ..._sessions];
    return saved;
  }

  @override
  Future<BreathSession> update(BreathSession session) async {
    _sessions = [
      for (final s in _sessions) s.id == session.id ? session : s,
    ];
    return session;
  }

  @override
  Future<void> delete(String id) async {
    _sessions = _sessions.where((s) => s.id != id).toList();
  }

  @override
  Future<void> starSession(String id, {required bool starred}) async {
    _sessions = [
      for (final s in _sessions)
        s.id == id ? s.copyWith(isStarred: starred) : s,
    ];
  }

  @override
  Future<void> deleteAll() async {
    deleteAllCount++;
    _sessions = [];
  }
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _user1 = User(id: 'user-1', email: 'a@b.com', name: 'A', language: '', isGuest: false);
final _user2 = User(id: 'user-2', email: 'c@d.com', name: 'C', language: '', isGuest: false);

BreathSession _session(String id) => BreathSession(
      id: id,
      userId: 'u',
      description: 'desc-$id',
      shared: false,
      exercises: [],
    );

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

({BreathSessionNotifier notifier, FakeBreathSessionRepository repo, BehaviorSubject<AuthState> authSubject})
    _make({User? initialUser}) {
  final repo = FakeBreathSessionRepository();
  final authSubject = BehaviorSubject<AuthState>.seeded(
    AuthenticatedState(initialUser ?? _user1),
  );
  final notifier = BreathSessionNotifier(repository: repo, authStream: authSubject.stream);
  return (notifier: notifier, repo: repo, authSubject: authSubject);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<String> _entryIds(BreathSessionsState state) =>
    state.entries.map((e) => e.session.id).toList();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('load()', () {
    test('null cursor replaces state entirely', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);

      await notifier.load(null, 10);

      expect(_entryIds(notifier.currentState), ['a', 'b']);

      notifier.dispose();
      await authSubject.close();
    });

    test('null cursor emits PageLoaded with correct entries', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);

      await notifier.load(null, 2);

      final event = notifier.currentState.lastEvent as PageLoaded;
      expect(event.entries.map((e) => e.session.id), ['a', 'b']);
      expect(event.nextCursor, isNull);

      notifier.dispose();
      await authSubject.close();
    });

    test('cursor appends entries without dedup', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b'), _session('c')]);

      await notifier.load(null, 2);
      final cursor = notifier.currentState.nextCursor;
      await notifier.load(cursor, 2);

      expect(_entryIds(notifier.currentState), ['a', 'b', 'c']);

      notifier.dispose();
      await authSubject.close();
    });

    test('null cursor updates existing entries', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);
      await notifier.load(null, 2);

      repo.seed([_session('a').copyWith(description: 'updated'), _session('b')]);
      await notifier.load(null, 2);

      expect(notifier.currentState.cachedById('a')!.description, 'updated');

      notifier.dispose();
      await authSubject.close();
    });

    test('concurrent load() — second call ignored while first in flight', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);

      final f1 = notifier.load(null, 10);
      final f2 = notifier.load(null, 10);
      await Future.wait([f1, f2]);

      expect(_entryIds(notifier.currentState), ['a']);

      notifier.dispose();
      await authSubject.close();
    });
  });

  group('refresh()', () {
    test('replaces state with fresh page', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);
      await notifier.load(null, 10);

      repo.seed([_session('x')]);
      await notifier.refresh(10);

      expect(_entryIds(notifier.currentState), ['x']);
      expect(notifier.currentState.cachedById('a'), isNull);

      notifier.dispose();
      await authSubject.close();
    });

    test('emits SessionsRefreshed event', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('x')]);
      await notifier.refresh(10);

      expect(notifier.currentState.lastEvent, isA<SessionsRefreshed>());

      notifier.dispose();
      await authSubject.close();
    });
  });

  group('create()', () {
    test('prepends new entry to entries list', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.load(null, 10);

      await notifier.create(_session('new'));

      expect(_entryIds(notifier.currentState).first, 'saved-new');

      notifier.dispose();
      await authSubject.close();
    });

    test('created entry is findable via cachedById', () async {
      final (:notifier, :repo, :authSubject) = _make();
      await notifier.create(_session('new'));

      expect(notifier.currentState.cachedById('saved-new'), isNotNull);

      notifier.dispose();
      await authSubject.close();
    });

    test('created entry has mine section', () async {
      final (:notifier, :repo, :authSubject) = _make();
      await notifier.create(_session('new'));

      final entry = notifier.currentState.entries.firstWhere((e) => e.session.id == 'saved-new');
      expect(entry.section, BreathListSection.mine);

      notifier.dispose();
      await authSubject.close();
    });

    test('emits SessionCreated event', () async {
      final (:notifier, :repo, :authSubject) = _make();
      await notifier.create(_session('new'));

      final event = notifier.currentState.lastEvent as SessionCreated;
      expect(event.session.id, 'saved-new');

      notifier.dispose();
      await authSubject.close();
    });
  });

  group('update()', () {
    test('updates session in all entries with matching id', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.load(null, 10);

      await notifier.update(_session('a').copyWith(description: 'changed'));

      expect(notifier.currentState.cachedById('a')!.description, 'changed');

      notifier.dispose();
      await authSubject.close();
    });

    test('preserves entry order', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);
      await notifier.load(null, 10);

      await notifier.update(_session('a').copyWith(description: 'changed'));

      expect(_entryIds(notifier.currentState), ['a', 'b']);

      notifier.dispose();
      await authSubject.close();
    });

    test('emits SessionUpdated event', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.load(null, 10);

      await notifier.update(_session('a').copyWith(description: 'changed'));

      expect(notifier.currentState.lastEvent, isA<SessionUpdated>());

      notifier.dispose();
      await authSubject.close();
    });
  });

  group('delete()', () {
    test('removes all entries with the id', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);
      await notifier.load(null, 10);

      await notifier.delete('a');

      expect(_entryIds(notifier.currentState), ['b']);
      expect(notifier.currentState.cachedById('a'), isNull);

      notifier.dispose();
      await authSubject.close();
    });

    test('emits SessionDeleted with the id', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.load(null, 10);

      await notifier.delete('a');

      final event = notifier.currentState.lastEvent as SessionDeleted;
      expect(event.id, 'a');

      notifier.dispose();
      await authSubject.close();
    });
  });

  group('starSession()', () {
    test('sets isStarred=true on existing entries and prepends a STARRED entry', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.load(null, 10);

      await notifier.starSession('a', starred: true);

      expect(notifier.currentState.cachedById('a')!.isStarred, isTrue);
      final starredEntry = notifier.currentState.entries.firstWhere(
        (e) => e.session.id == 'a' && e.section == BreathListSection.starred,
        orElse: () => throw StateError('No STARRED entry for a'),
      );
      expect(starredEntry.section, BreathListSection.starred);

      notifier.dispose();
      await authSubject.close();
    });

    test('unstar removes STARRED entry and sets isStarred=false on remaining', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.load(null, 10);
      await notifier.starSession('a', starred: true);

      await notifier.starSession('a', starred: false);

      final hasStarredEntry = notifier.currentState.entries
          .any((e) => e.session.id == 'a' && e.section == BreathListSection.starred);
      expect(hasStarredEntry, isFalse);
      // The mine entry should still exist with isStarred=false
      final mineEntry = notifier.currentState.entries.firstWhere(
        (e) => e.session.id == 'a' && e.section == BreathListSection.mine,
      );
      expect(mineEntry.session.isStarred, isFalse);

      notifier.dispose();
      await authSubject.close();
    });

    test('unstar starred-only entry completes without throwing and removes the entry', () async {
      // Simulates the case where the first loaded page contains only STARRED entries
      // (MINE/SHARED duplicates are on a later, not-yet-loaded page).
      final repo = FakeBreathSessionRepository();
      repo.sectionForFetch = BreathListSection.starred;
      final authSubject = BehaviorSubject<AuthState>.seeded(AuthenticatedState(_user1));
      final notifier = BreathSessionNotifier(repository: repo, authStream: authSubject.stream);

      repo.seed([_session('a')]);
      await notifier.load(null, 10);
      // State: only one STARRED entry for 'a'
      expect(notifier.currentState.entries.length, 1);
      expect(notifier.currentState.entries.first.section, BreathListSection.starred);

      await expectLater(notifier.starSession('a', starred: false), completes);

      final hasAnyEntry = notifier.currentState.entries.any((e) => e.session.id == 'a');
      expect(hasAnyEntry, isFalse);
      expect(notifier.currentState.lastEvent, isA<SessionStarred>());

      notifier.dispose();
      await authSubject.close();
    });

    test('emits SessionStarred event', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.load(null, 10);

      await notifier.starSession('a', starred: true);

      expect(notifier.currentState.lastEvent, isA<SessionStarred>());

      notifier.dispose();
      await authSubject.close();
    });

    test('no-ops silently if session not found in state — no phantom entry added', () async {
      final (:notifier, :repo, :authSubject) = _make();
      final initialEntryCount = notifier.currentState.entries.length;

      await notifier.starSession('nonexistent', starred: true);

      expect(notifier.currentState.entries.length, initialEntryCount);

      notifier.dispose();
      await authSubject.close();
    });
  });

  group('user change', () {
    test('user id change calls deleteAll and emits empty entries with SessionsInvalidated', () async {
      final (:notifier, :repo, :authSubject) = _make(initialUser: _user1);
      repo.seed([_session('a')]);
      await notifier.load(null, 10);
      expect(_entryIds(notifier.currentState), ['a']);

      authSubject.add(AuthenticatedState(_user2));
      await Future.delayed(Duration.zero);

      expect(notifier.currentState.entries, isEmpty);
      expect(notifier.currentState.nextCursor, isNull);
      expect(notifier.currentState.lastEvent, isA<SessionsInvalidated>());
      expect(repo.deleteAllCount, 1);

      notifier.dispose();
      await authSubject.close();
    });

    test('same user id does NOT trigger invalidation', () async {
      final (:notifier, :repo, :authSubject) = _make(initialUser: _user1);
      repo.seed([_session('a')]);
      await notifier.load(null, 10);

      authSubject.add(AuthenticatedState(_user1));
      await Future.delayed(Duration.zero);

      expect(_entryIds(notifier.currentState), ['a']);
      expect(repo.deleteAllCount, 0);

      notifier.dispose();
      await authSubject.close();
    });
  });
}
