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
  /// Controls the section tag returned by fetch/refresh.
  /// Ignored by the notifier (sections are now derived locally), but kept
  /// so tests can control what raw entries the repo returns.
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

/// Creates an owned session (userId == _user1.id) so it resolves to MINE.
/// Use an explicit [userId] argument to create a SHARED session.
BreathSession _session(String id, {String? userId, bool isStarred = false, DateTime? createdAt}) =>
    BreathSession(
      id: id,
      userId: userId ?? 'user-1',
      description: 'desc-$id',
      shared: false,
      isStarred: isStarred,
      createdAt: createdAt,
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
  final notifier = BreathSessionNotifier(
    repository: repo,
    authStream: authSubject.stream,
    currentUserId: () => authSubject.value.user.id,
  );
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

    test('cursor appends unique sessions, within-section order by createdAt DESC then id', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b'), _session('c')]);

      await notifier.load(null, 2);
      final cursor = notifier.currentState.nextCursor;
      await notifier.load(cursor, 2);

      final ids = _entryIds(notifier.currentState);
      expect(ids.toSet().length, ids.length, reason: 'no duplicate ids for non-starred sessions');
      expect(ids, containsAll(['a', 'b', 'c']));

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

    test('starred session yields both MINE and STARRED entries after load', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a', isStarred: true)]);

      await notifier.load(null, 10);

      final entries = notifier.currentState.entries;
      final mineEntry = entries.where(
        (e) => e.session.id == 'a' && e.section == BreathListSection.mine,
      );
      final starredEntry = entries.where(
        (e) => e.session.id == 'a' && e.section == BreathListSection.starred,
      );
      expect(mineEntry.length, 1, reason: 'exactly one MINE entry for starred session');
      expect(starredEntry.length, 1, reason: 'exactly one STARRED entry for starred session');
      expect(entries.every((e) => e.session.isStarred), isTrue);

      notifier.dispose();
      await authSubject.close();
    });

    test('uniqueSessions OR-ing: isStarred=true wins when id appears multiple times', () async {
      // Simulates two pages containing the same id — one page has isStarred=true,
      // the other has isStarred=false. The merged result should treat the session as starred.
      final (:notifier, :repo, :authSubject) = _make();
      // Page 1: 'a' not starred; page 2 overlap: 'a' starred (different seedings).
      repo.seed([_session('a', isStarred: false), _session('b')]);
      await notifier.load(null, 10);

      // Reload first page where 'a' is now starred — simulates server sending updated data.
      repo.seed([_session('a', isStarred: true), _session('b')]);
      await notifier.load(null, 10);

      expect(notifier.currentState.cachedById('a')!.isStarred, isTrue);
      final hasStarred = notifier.currentState.entries
          .any((e) => e.session.id == 'a' && e.section == BreathListSection.starred);
      expect(hasStarred, isTrue);

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
    test('new entry is present in entries list', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.load(null, 10);

      // Use a newer createdAt so saved-new sorts first (builder sorts DESC by createdAt).
      await notifier.create(_session('new', createdAt: DateTime(2030)));

      expect(_entryIds(notifier.currentState), contains('saved-new'));

      notifier.dispose();
      await authSubject.close();
    });

    test('new entry sorts first when it has the newest createdAt', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.load(null, 10);

      await notifier.create(_session('new', createdAt: DateTime(2030)));

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
    test('sets isStarred=true on existing entries and adds a STARRED entry', () async {
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

    test('unstar removes STARRED entry and MINE entry remains with isStarred=false', () async {
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

    test('unstar starred session removes STARRED entry and keeps MINE/SHARED entry', () async {
      // The builder always emits a MINE/SHARED entry regardless of star status.
      // Unstarring only removes the STARRED duplicate; ownership entry always remains.
      final repo = FakeBreathSessionRepository();
      final authSubject = BehaviorSubject<AuthState>.seeded(AuthenticatedState(_user1));
      final notifier = BreathSessionNotifier(
        repository: repo,
        authStream: authSubject.stream,
        currentUserId: () => authSubject.value.user.id,
      );

      repo.seed([_session('a', isStarred: true)]);
      await notifier.load(null, 10);

      // After load: should have both MINE and STARRED entries.
      expect(notifier.currentState.entries.where((e) => e.section == BreathListSection.starred).length, 1);
      expect(notifier.currentState.entries.where((e) => e.section == BreathListSection.mine).length, 1);

      await expectLater(notifier.starSession('a', starred: false), completes);

      // STARRED duplicate is gone; MINE entry remains.
      final hasStarredEntry = notifier.currentState.entries
          .any((e) => e.session.id == 'a' && e.section == BreathListSection.starred);
      expect(hasStarredEntry, isFalse, reason: 'STARRED duplicate should be removed after unstar');

      final hasMineEntry = notifier.currentState.entries
          .any((e) => e.session.id == 'a' && e.section == BreathListSection.mine);
      expect(hasMineEntry, isTrue, reason: 'MINE entry should remain after unstar');

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

    test('starred own session appears in both STARRED and MINE sections', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.load(null, 10);
      await notifier.starSession('a', starred: true);

      final entries = notifier.currentState.entries;
      expect(entries.any((e) => e.session.id == 'a' && e.section == BreathListSection.mine), isTrue);
      expect(entries.any((e) => e.session.id == 'a' && e.section == BreathListSection.starred), isTrue);

      notifier.dispose();
      await authSubject.close();
    });

    test('starred shared session appears in both STARRED and SHARED sections', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a', userId: 'other-user')]);
      await notifier.load(null, 10);
      await notifier.starSession('a', starred: true);

      final entries = notifier.currentState.entries;
      expect(entries.any((e) => e.session.id == 'a' && e.section == BreathListSection.shared), isTrue);
      expect(entries.any((e) => e.session.id == 'a' && e.section == BreathListSection.starred), isTrue);

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
