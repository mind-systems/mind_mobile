import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';

import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/BreathModule/Core/IBreathSessionRepository.dart';
import 'package:mind/BreathModule/Core/Models/BreathSessionNotifierEvent.dart';
import 'package:mind/BreathModule/Models/BreathListSection.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Models/User.dart';

// ---------------------------------------------------------------------------
// Fake repository
// ---------------------------------------------------------------------------

class FakeBreathSessionRepository implements IBreathSessionRepository {
  List<BreathSession> _sessions = [];
  int deleteAllCount = 0;

  void seed(List<BreathSession> sessions) => _sessions = List.of(sessions);

  @override
  Future<BreathSession> fetchById(String id) async =>
      _sessions.firstWhere((s) => s.id == id);

  int refreshCallCount = 0;
  List<int> refreshPageSizes = [];

  /// No-op — the notifier calls localSessions() after this returns.
  @override
  Future<void> refresh(int pageSize) async {
    refreshCallCount++;
    refreshPageSizes.add(pageSize);
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

  @override
  Future<List<BreathSession>> localSessions() async => List.of(_sessions);
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
  group('refresh()', () {
    test('populates state from local sessions after refresh', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);

      await notifier.refresh(10);

      expect(_entryIds(notifier.currentState), ['a', 'b']);

      notifier.dispose();
      await authSubject.close();
    });

    test('replaces state with fresh sessions', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);
      await notifier.refresh(10);

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

    test('concurrent refresh() — second call ignored while first in flight', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);

      final f1 = notifier.refresh(10);
      final f2 = notifier.refresh(10);
      await Future.wait([f1, f2]);

      expect(_entryIds(notifier.currentState), ['a']);

      notifier.dispose();
      await authSubject.close();
    });

    test('starred session yields both MINE and STARRED entries after refresh', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a', isStarred: true)]);

      await notifier.refresh(10);

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

    test('updates existing entries on re-refresh', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);
      await notifier.refresh(10);

      repo.seed([_session('a').copyWith(description: 'updated'), _session('b')]);
      await notifier.refresh(10);

      expect(notifier.currentState.cachedById('a')!.description, 'updated');

      notifier.dispose();
      await authSubject.close();
    });
  });

  group('create()', () {
    test('new entry is present in entries list', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.refresh(10);

      // Use a newer createdAt so saved-new sorts first (builder sorts DESC by createdAt).
      await notifier.create(_session('new', createdAt: DateTime(2030)));

      expect(_entryIds(notifier.currentState), contains('saved-new'));

      notifier.dispose();
      await authSubject.close();
    });

    test('new entry sorts first when it has the newest createdAt', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.refresh(10);

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
      await notifier.refresh(10);

      await notifier.update(_session('a').copyWith(description: 'changed'));

      expect(notifier.currentState.cachedById('a')!.description, 'changed');

      notifier.dispose();
      await authSubject.close();
    });

    test('preserves entry order', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);
      await notifier.refresh(10);

      await notifier.update(_session('a').copyWith(description: 'changed'));

      expect(_entryIds(notifier.currentState), ['a', 'b']);

      notifier.dispose();
      await authSubject.close();
    });

    test('emits SessionUpdated event', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.refresh(10);

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
      await notifier.refresh(10);

      await notifier.delete('a');

      expect(_entryIds(notifier.currentState), ['b']);
      expect(notifier.currentState.cachedById('a'), isNull);

      notifier.dispose();
      await authSubject.close();
    });

    test('emits SessionDeleted with the id', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.refresh(10);

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
      await notifier.refresh(10);

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
      await notifier.refresh(10);
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
      await notifier.refresh(10);

      // After refresh: should have both MINE and STARRED entries.
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
      await notifier.refresh(10);

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
      await notifier.refresh(10);
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
      await notifier.refresh(10);
      await notifier.starSession('a', starred: true);

      final entries = notifier.currentState.entries;
      expect(entries.any((e) => e.session.id == 'a' && e.section == BreathListSection.shared), isTrue);
      expect(entries.any((e) => e.session.id == 'a' && e.section == BreathListSection.starred), isTrue);

      notifier.dispose();
      await authSubject.close();
    });
  });

  group('refresh() — write-through delegation', () {
    test('should call repository.refresh exactly once per refresh()', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);

      await notifier.refresh(10);

      expect(repo.refreshCallCount, 1);

      notifier.dispose();
      await authSubject.close();
    });

    test('should forward the page size to repository.refresh', () async {
      final (:notifier, :repo, :authSubject) = _make();

      await notifier.refresh(25);

      expect(repo.refreshPageSizes, [25]);

      notifier.dispose();
      await authSubject.close();
    });

    test('should re-read Drift after repository.refresh completes and replace stale entries', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('old')]);
      await notifier.refresh(10);

      repo.seed([_session('new')]);
      await notifier.refresh(10);

      expect(_entryIds(notifier.currentState), ['new']);
      expect(notifier.currentState.cachedById('old'), isNull);

      notifier.dispose();
      await authSubject.close();
    });

    test('should not run a second refresh() while one is in flight', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);

      final f1 = notifier.refresh(10);
      final f2 = notifier.refresh(10);
      await Future.wait([f1, f2]);

      expect(repo.refreshCallCount, 1);

      notifier.dispose();
      await authSubject.close();
    });
  });

  group('loadLocal()', () {
    test('should leave entries empty before loadLocal() is called when Drift has data', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);

      // Constructor does no Drift read — state is still empty before awaiting loadLocal().
      expect(notifier.currentState.entries, isEmpty);

      notifier.dispose();
      await authSubject.close();
    });

    test('should populate entries from Drift after loadLocal()', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);

      await notifier.loadLocal();

      expect(notifier.currentState.entries, isNotEmpty);
      expect(_entryIds(notifier.currentState), containsAll(['a', 'b']));

      notifier.dispose();
      await authSubject.close();
    });

    test('should emit LocalSessionsLoaded event after loadLocal() with non-empty Drift', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);

      await notifier.loadLocal();

      expect(notifier.currentState.lastEvent, isA<LocalSessionsLoaded>());

      notifier.dispose();
      await authSubject.close();
    });

    test('should return early without emitting when Drift is empty', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([]);

      await notifier.loadLocal();

      expect(notifier.currentState.entries, isEmpty);
      expect(notifier.currentState.lastEvent, isNull);

      notifier.dispose();
      await authSubject.close();
    });
  });

  group('invalidate()', () {
    test('should re-read updated Drift state on invalidate() without calling repository.refresh', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('initial')]);
      await notifier.refresh(10);

      repo.seed([_session('initial').copyWith(description: 'updated')]);
      final countBefore = repo.refreshCallCount;
      await notifier.invalidate();

      expect(notifier.currentState.cachedById('initial')!.description, 'updated');
      expect(repo.refreshCallCount, countBefore);

      notifier.dispose();
      await authSubject.close();
    });

    test('should emit LocalSessionsLoaded event on invalidate()', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.refresh(10);

      repo.seed([_session('a').copyWith(description: 'updated')]);
      await notifier.invalidate();

      expect(notifier.currentState.lastEvent, isA<LocalSessionsLoaded>());

      notifier.dispose();
      await authSubject.close();
    });

    test('should emit empty entries on invalidate() when Drift is empty', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.refresh(10);

      repo.seed([]);
      await notifier.invalidate();

      expect(notifier.currentState.entries, isEmpty);

      notifier.dispose();
      await authSubject.close();
    });
  });

  group('section derivation', () {
    // --- Task 5: ownership (MINE / SHARED) ---

    test('should emit a MINE entry for a session owned by the current user', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.refresh(10);

      final entry = notifier.currentState.entries.firstWhere((e) => e.session.id == 'a');
      expect(entry.section, BreathListSection.mine);

      notifier.dispose();
      await authSubject.close();
    });

    test('should emit a SHARED entry for a session owned by another user', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a', userId: 'other-user')]);
      await notifier.refresh(10);

      final entry = notifier.currentState.entries.firstWhere((e) => e.session.id == 'a');
      expect(entry.section, BreathListSection.shared);

      notifier.dispose();
      await authSubject.close();
    });

    test('should emit no STARRED entry for an unstarred session', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.refresh(10);

      final hasStarred = notifier.currentState.entries.any((e) => e.section == BreathListSection.starred);
      expect(hasStarred, isFalse);
      expect(notifier.currentState.entries.length, 1);

      notifier.dispose();
      await authSubject.close();
    });

    // --- Task 6: STARRED duplicate ---

    test('should emit both MINE and STARRED entries for a starred owned session', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a', isStarred: true)]);
      await notifier.refresh(10);

      final entries = notifier.currentState.entries;
      final mineCount = entries.where((e) => e.session.id == 'a' && e.section == BreathListSection.mine).length;
      final starredCount = entries.where((e) => e.session.id == 'a' && e.section == BreathListSection.starred).length;

      expect(mineCount, 1);
      expect(starredCount, 1);
      expect(entries.length, 2);

      notifier.dispose();
      await authSubject.close();
    });

    test('should emit both SHARED and STARRED entries for a starred shared session', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a', userId: 'other-user', isStarred: true)]);
      await notifier.refresh(10);

      final entries = notifier.currentState.entries;
      final hasShared = entries.any((e) => e.session.id == 'a' && e.section == BreathListSection.shared);
      final hasStarred = entries.any((e) => e.session.id == 'a' && e.section == BreathListSection.starred);

      expect(hasShared, isTrue);
      expect(hasStarred, isTrue);

      notifier.dispose();
      await authSubject.close();
    });

    // --- Task 7: sort order and tie-breaker ---

    test('should order entries by createdAt DESC', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([
        _session('a', createdAt: DateTime(2020)),
        _session('b', createdAt: DateTime(2025)),
        _session('c', createdAt: DateTime(2022)),
      ]);
      await notifier.refresh(10);

      expect(_entryIds(notifier.currentState), ['b', 'c', 'a']);

      notifier.dispose();
      await authSubject.close();
    });

    test('should break createdAt ties by id ASC', () async {
      final (:notifier, :repo, :authSubject) = _make();
      final sameDate = DateTime(2023, 6, 15);
      repo.seed([
        _session('z', createdAt: sameDate),
        _session('a', createdAt: sameDate),
      ]);
      await notifier.refresh(10);

      expect(_entryIds(notifier.currentState), ['a', 'z']);

      notifier.dispose();
      await authSubject.close();
    });

    test('should keep the STARRED duplicate adjacent to its ownership entry in the sorted stream', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([
        _session('star', isStarred: true, createdAt: DateTime(2025)),
        _session('older1', createdAt: DateTime(2022)),
        _session('older2', createdAt: DateTime(2020)),
      ]);
      await notifier.refresh(10);

      final entries = notifier.currentState.entries;
      final hasMine = entries.any((e) => e.session.id == 'star' && e.section == BreathListSection.mine);
      final hasStarred = entries.any((e) => e.session.id == 'star' && e.section == BreathListSection.starred);

      expect(hasMine, isTrue);
      expect(hasStarred, isTrue);

      notifier.dispose();
      await authSubject.close();
    });
  });

  group('user change', () {
    test('user id change calls deleteAll and emits empty entries with LocalSessionsLoaded', () async {
      final (:notifier, :repo, :authSubject) = _make(initialUser: _user1);
      repo.seed([_session('a')]);
      await notifier.refresh(10);
      expect(_entryIds(notifier.currentState), ['a']);

      authSubject.add(AuthenticatedState(_user2));
      await Future.delayed(Duration.zero);

      expect(notifier.currentState.entries, isEmpty);
      expect(notifier.currentState.lastEvent, isA<LocalSessionsLoaded>());
      expect(repo.deleteAllCount, 1);

      notifier.dispose();
      await authSubject.close();
    });

    test('same user id does NOT trigger invalidation', () async {
      final (:notifier, :repo, :authSubject) = _make(initialUser: _user1);
      repo.seed([_session('a')]);
      await notifier.refresh(10);

      authSubject.add(AuthenticatedState(_user1));
      await Future.delayed(Duration.zero);

      expect(_entryIds(notifier.currentState), ['a']);
      expect(repo.deleteAllCount, 0);

      notifier.dispose();
      await authSubject.close();
    });
  });
}
