import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';

import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/BreathModule/Core/IBreathSessionRepository.dart';
import 'package:mind/BreathModule/Core/Models/BreathSessionNotifierEvent.dart';
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

  @override
  Future<({List<BreathSession> sessions, bool hasMore})> fetch(
      int page, int pageSize) async {
    final offset = page * pageSize;
    final slice = _sessions.skip(offset).take(pageSize).toList();
    final hasMore = offset + slice.length < _sessions.length;
    return (sessions: slice, hasMore: hasMore);
  }

  @override
  Future<({List<BreathSession> sessions, bool hasMore})> refresh(
      int pageSize) async {
    final slice = _sessions.take(pageSize).toList();
    final hasMore = slice.length < _sessions.length;
    return (sessions: slice, hasMore: hasMore);
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
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('load()', () {
    test('page 0 replaces state entirely', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);

      await notifier.load(0, 10);

      expect(notifier.currentState.order, ['a', 'b']);
      expect(notifier.currentState.byId.keys, containsAll(['a', 'b']));

      notifier.dispose();
      await authSubject.close();
    });

    test('page 0 emits PageLoaded with correct fields', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);

      await notifier.load(0, 2);

      final event = notifier.currentState.lastEvent as PageLoaded;
      expect(event.page, 0);
      expect(event.sessions.map((s) => s.id), ['a', 'b']);
      expect(event.hasMore, isFalse);

      notifier.dispose();
      await authSubject.close();
    });

    test('page 1 appends only new sessions to order', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b'), _session('c')]);

      await notifier.load(0, 2);
      await notifier.load(1, 2);

      expect(notifier.currentState.order, ['a', 'b', 'c']);

      notifier.dispose();
      await authSubject.close();
    });

    test('page 1 updates byId for already-known ids', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);
      await notifier.load(0, 2);

      repo.seed([_session('a').copyWith(description: 'updated'), _session('b')]);
      await notifier.load(0, 2);

      expect(notifier.currentState.byId['a']!.description, 'updated');

      notifier.dispose();
      await authSubject.close();
    });

    test('concurrent load() — second call ignored while first in flight', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);

      final f1 = notifier.load(0, 10);
      final f2 = notifier.load(0, 10);
      await Future.wait([f1, f2]);

      expect(notifier.currentState.order, ['a']);

      notifier.dispose();
      await authSubject.close();
    });
  });

  group('refresh()', () {
    test('replaces state with fresh page', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);
      await notifier.load(0, 10);

      repo.seed([_session('x')]);
      await notifier.refresh(10);

      expect(notifier.currentState.order, ['x']);
      expect(notifier.currentState.byId.containsKey('a'), isFalse);

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
    test('prepends new session to order', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.load(0, 10);

      await notifier.create(_session('new'));

      expect(notifier.currentState.order.first, 'saved-new');

      notifier.dispose();
      await authSubject.close();
    });

    test('adds to byId', () async {
      final (:notifier, :repo, :authSubject) = _make();
      await notifier.create(_session('new'));

      expect(notifier.currentState.byId.containsKey('saved-new'), isTrue);

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
    test('updates entry in byId', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.load(0, 10);

      await notifier.update(_session('a').copyWith(description: 'changed'));

      expect(notifier.currentState.byId['a']!.description, 'changed');

      notifier.dispose();
      await authSubject.close();
    });

    test('does not change order', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);
      await notifier.load(0, 10);

      await notifier.update(_session('a').copyWith(description: 'changed'));

      expect(notifier.currentState.order, ['a', 'b']);

      notifier.dispose();
      await authSubject.close();
    });

    test('emits SessionUpdated event', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.load(0, 10);

      await notifier.update(_session('a').copyWith(description: 'changed'));

      expect(notifier.currentState.lastEvent, isA<SessionUpdated>());

      notifier.dispose();
      await authSubject.close();
    });
  });

  group('delete()', () {
    test('removes from byId and order', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a'), _session('b')]);
      await notifier.load(0, 10);

      await notifier.delete('a');

      expect(notifier.currentState.order, ['b']);
      expect(notifier.currentState.byId.containsKey('a'), isFalse);

      notifier.dispose();
      await authSubject.close();
    });

    test('emits SessionDeleted with the id', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.load(0, 10);

      await notifier.delete('a');

      final event = notifier.currentState.lastEvent as SessionDeleted;
      expect(event.id, 'a');

      notifier.dispose();
      await authSubject.close();
    });
  });

  group('starSession()', () {
    test('updates isStarred in byId', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.load(0, 10);

      await notifier.starSession('a', starred: true);

      expect(notifier.currentState.byId['a']!.isStarred, isTrue);

      notifier.dispose();
      await authSubject.close();
    });

    test('emits SessionStarred event', () async {
      final (:notifier, :repo, :authSubject) = _make();
      repo.seed([_session('a')]);
      await notifier.load(0, 10);

      await notifier.starSession('a', starred: true);

      expect(notifier.currentState.lastEvent, isA<SessionStarred>());

      notifier.dispose();
      await authSubject.close();
    });

    test('no-ops silently if session not found in state', () async {
      final (:notifier, :repo, :authSubject) = _make();

      await expectLater(
        notifier.starSession('nonexistent', starred: true),
        completes,
      );

      notifier.dispose();
      await authSubject.close();
    });
  });

  group('user change', () {
    test('user id change calls deleteAll and emits empty state with SessionsInvalidated', () async {
      final (:notifier, :repo, :authSubject) = _make(initialUser: _user1);
      repo.seed([_session('a')]);
      await notifier.load(0, 10);
      expect(notifier.currentState.order, ['a']);

      authSubject.add(AuthenticatedState(_user2));
      await Future.delayed(Duration.zero);

      expect(notifier.currentState.order, isEmpty);
      expect(notifier.currentState.byId, isEmpty);
      expect(notifier.currentState.lastEvent, isA<SessionsInvalidated>());
      expect(repo.deleteAllCount, 1);

      notifier.dispose();
      await authSubject.close();
    });

    test('same user id does NOT trigger invalidation', () async {
      final (:notifier, :repo, :authSubject) = _make(initialUser: _user1);
      repo.seed([_session('a')]);
      await notifier.load(0, 10);

      authSubject.add(AuthenticatedState(_user1));
      await Future.delayed(Duration.zero);

      expect(notifier.currentState.order, ['a']);
      expect(repo.deleteAllCount, 0);

      notifier.dispose();
      await authSubject.close();
    });
  });
}
