import 'package:flutter_test/flutter_test.dart';
import 'package:mind/BreathModule/Core/BreathSessionRepository.dart';
import 'package:mind/BreathModule/Models/BreathListSection.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/BreathSessionsListResponse.dart';
import 'package:mind/BreathModule/Core/IBreathSessionApi.dart';
import 'package:mind/Core/Api/Models/SaveBreathSessionRequest.dart';
import 'package:mind/Core/Api/Models/StarSessionRequest.dart';
import 'package:mind/Core/Database/IBreathSessionDao.dart';


// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeBreathSessionDao implements IBreathSessionDao {
  final List<BreathSession> _sessions = [];

  @override
  Future<List<BreathSession>> getSessions({int? limit, int? offset}) async {
    final all = List<BreathSession>.unmodifiable(_sessions);
    final start = offset ?? 0;
    if (start >= all.length) return [];
    final end = limit != null ? (start + limit).clamp(0, all.length) : all.length;
    return all.sublist(start, end);
  }

  @override
  Future<BreathSession?> getSessionById(String id) async {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<void> saveSession(BreathSession session) async {
    _sessions.removeWhere((s) => s.id == session.id);
    _sessions.add(session);
  }

  @override
  Future<void> saveSessions(List<BreathSession> sessions) async {
    for (final session in sessions) {
      await saveSession(session);
    }
  }

  @override
  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
  }

  @override
  Future<void> deleteAllSessions() async {
    _sessions.clear();
  }
}

class FakeBreathSessionApi implements IBreathSessionApi {
  final List<BreathSession> _sessions;

  bool createCalled = false;
  bool updateCalled = false;
  bool deleteCalled = false;
  bool starCalled = false;
  String? lastDeletedId;
  String? lastFetchCursor;
  int? lastFetchPageSize;

  FakeBreathSessionApi({List<BreathSession>? sessions})
      : _sessions = sessions ?? [];

  @override
  Future<BreathSession> create(SaveBreathSessionRequest request) async {
    createCalled = true;
    final session = BreathSession(
      id: 'created-id',
      userId: 'user-1',
      description: request.description,
      shared: request.shared,
      exercises: request.exercises,
    );
    _sessions.add(session);
    return session;
  }

  @override
  Future<BreathSession> update(String id, SaveBreathSessionRequest request) async {
    updateCalled = true;
    final session = BreathSession(
      id: id,
      userId: 'user-1',
      description: request.description,
      shared: request.shared,
      exercises: request.exercises,
    );
    _sessions.removeWhere((s) => s.id == id);
    _sessions.add(session);
    return session;
  }

  @override
  Future<void> delete(String sessionId) async {
    deleteCalled = true;
    lastDeletedId = sessionId;
    _sessions.removeWhere((s) => s.id == sessionId);
  }

  @override
  Future<BreathSession> fetchById(String id) async {
    return _sessions.firstWhere((s) => s.id == id);
  }

  @override
  Future<BreathSessionsListResponse> fetchPage(String? cursor, int pageSize) async {
    lastFetchCursor = cursor;
    lastFetchPageSize = pageSize;
    final offset = cursor != null ? int.parse(cursor.split(':')[1]) : 0;
    if (offset >= _sessions.length) {
      return const BreathSessionsListResponse(entries: [], nextCursor: null);
    }
    final end = (offset + pageSize).clamp(0, _sessions.length);
    final slice = _sessions.sublist(offset, end);
    final nextOffset = offset + slice.length;
    final nextCursor = nextOffset < _sessions.length ? 'offset:$nextOffset' : null;
    final entries = slice
        .map((s) => BreathSessionListEntry(session: s, section: BreathListSection.mine))
        .toList();
    return BreathSessionsListResponse(entries: entries, nextCursor: nextCursor);
  }

  @override
  Future<void> starSession(StarSessionRequest request) async {
    starCalled = true;
  }
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

BreathSession _makeSession(String id) => BreathSession(
      id: id,
      userId: 'user-1',
      description: 'Test session $id',
      shared: false,
      exercises: const [],
    );

List<BreathSession> _makeSessions(int count) =>
    List.generate(count, (i) => _makeSession('s${i + 1}'));

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

BreathSessionRepository _makeRepo({
  FakeBreathSessionDao? dao,
  FakeBreathSessionApi? api,
}) {
  return BreathSessionRepository(
    dao: dao ?? FakeBreathSessionDao(),
    api: api ?? FakeBreathSessionApi(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('fetchById', () {
    test('returns cached DB session without calling API', () async {
      final dao = FakeBreathSessionDao();
      final session = _makeSession('s1');
      await dao.saveSession(session);

      final api = FakeBreathSessionApi();
      final repo = _makeRepo(dao: dao, api: api);

      final result = await repo.fetchById('s1');

      expect(result.id, 's1');
      expect(api.lastFetchCursor, isNull); // API not called
    });

    test('falls back to API when session not in DB', () async {
      final session = _makeSession('s2');
      final api = FakeBreathSessionApi(sessions: [session]);
      final repo = _makeRepo(api: api);

      final result = await repo.fetchById('s2');

      expect(result.id, 's2');
    });
  });

  group('fetch', () {
    test('calls API with null cursor for first page', () async {
      final dao = FakeBreathSessionDao();
      final apiSessions = _makeSessions(10);
      final api = FakeBreathSessionApi(sessions: apiSessions);
      final repo = _makeRepo(dao: dao, api: api);

      final result = await repo.fetch(null, 10);

      expect(api.lastFetchCursor, isNull);
      expect(result.entries.length, 10);
      expect(result.entries.map((e) => e.session.id).first, 's1');
    });

    test('passes cursor to API for subsequent pages', () async {
      final dao = FakeBreathSessionDao();
      final apiSessions = _makeSessions(15);
      final api = FakeBreathSessionApi(sessions: apiSessions);
      final repo = _makeRepo(dao: dao, api: api);

      await repo.fetch(null, 10);
      await repo.fetch('offset:10', 10);

      expect(api.lastFetchCursor, 'offset:10');
    });

    test('upserts fetched sessions into DAO', () async {
      final dao = FakeBreathSessionDao();
      final apiSessions = _makeSessions(5);
      final api = FakeBreathSessionApi(sessions: apiSessions);
      final repo = _makeRepo(dao: dao, api: api);

      await repo.fetch(null, 5);

      final cached = await dao.getSessions();
      expect(cached.length, 5);
    });

    test('returns nextCursor when more pages exist', () async {
      final dao = FakeBreathSessionDao();
      final apiSessions = _makeSessions(15);
      final api = FakeBreathSessionApi(sessions: apiSessions);
      final repo = _makeRepo(dao: dao, api: api);

      final result = await repo.fetch(null, 10);

      expect(result.nextCursor, isNotNull);
    });

    test('returns null nextCursor on last page', () async {
      final dao = FakeBreathSessionDao();
      final apiSessions = _makeSessions(5);
      final api = FakeBreathSessionApi(sessions: apiSessions);
      final repo = _makeRepo(dao: dao, api: api);

      final result = await repo.fetch(null, 10);

      expect(result.nextCursor, isNull);
    });
  });

  group('refresh', () {
    test('calls API with null cursor', () async {
      final dao = FakeBreathSessionDao();
      final apiSessions = _makeSessions(5);
      final api = FakeBreathSessionApi(sessions: apiSessions);
      final repo = _makeRepo(dao: dao, api: api);

      await repo.refresh(10);

      expect(api.lastFetchCursor, isNull);
    });

    test('upserts sessions into DAO without deleting existing rows', () async {
      final dao = FakeBreathSessionDao();
      // Pre-populate DAO with a session not in the API response (e.g. a detail-cached session)
      await dao.saveSession(_makeSession('detail-only'));
      final apiSessions = _makeSessions(3);
      final api = FakeBreathSessionApi(sessions: apiSessions);
      final repo = _makeRepo(dao: dao, api: api);

      await repo.refresh(10);

      // The pre-existing session should still be in the DAO (write-through, no delete)
      final detailSession = await dao.getSessionById('detail-only');
      expect(detailSession, isNotNull);
      // New sessions from the API should also be cached
      final s1 = await dao.getSessionById('s1');
      expect(s1, isNotNull);
    });

    test('returns entries from first page', () async {
      final dao = FakeBreathSessionDao();
      final apiSessions = _makeSessions(3);
      final api = FakeBreathSessionApi(sessions: apiSessions);
      final repo = _makeRepo(dao: dao, api: api);

      final result = await repo.refresh(10);

      expect(result.entries.length, 3);
    });
  });

  group('create', () {
    test('calls api.create and persists to DAO', () async {
      final dao = FakeBreathSessionDao();
      final api = FakeBreathSessionApi();
      final repo = _makeRepo(dao: dao, api: api);
      final session = _makeSession('s5');

      await repo.create(session);

      expect(api.createCalled, true);

      final stored = await dao.getSessionById('created-id');
      expect(stored, isNotNull);
    });
  });

  group('delete', () {
    test('calls api.delete and removes from DAO', () async {
      final dao = FakeBreathSessionDao();
      final session = _makeSession('s6');
      await dao.saveSession(session);
      final api = FakeBreathSessionApi(sessions: [session]);
      final repo = _makeRepo(dao: dao, api: api);

      await repo.delete('s6');

      expect(api.deleteCalled, true);
      expect(api.lastDeletedId, 's6');

      final stored = await dao.getSessionById('s6');
      expect(stored, isNull);
    });
  });
}
