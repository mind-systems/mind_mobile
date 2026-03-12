import 'package:flutter_test/flutter_test.dart';
import 'package:mind/BreathModule/Core/BreathSessionRepository.dart';
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
  int? lastFetchPage;
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
  Future<BreathSessionsListResponse> fetchAll(int page, int pageSize) async {
    lastFetchPage = page;
    lastFetchPageSize = pageSize;
    // 1-based pagination matching server contract
    final offset = (page - 1) * pageSize;
    if (offset >= _sessions.length) {
      return BreathSessionsListResponse(
        data: [],
        total: _sessions.length,
        page: page,
        pageSize: pageSize,
      );
    }
    final end = (offset + pageSize).clamp(0, _sessions.length);
    return BreathSessionsListResponse(
      data: _sessions.sublist(offset, end),
      total: _sessions.length,
      page: page,
      pageSize: pageSize,
    );
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
    });

    test('falls back to API when session not in DB', () async {
      final session = _makeSession('s2');
      final api = FakeBreathSessionApi(sessions: [session]);
      final repo = _makeRepo(api: api);

      final result = await repo.fetchById('s2');

      expect(result.id, 's2');
    });
  });

  group('fetch — DAO cache', () {
    test('returns page from DAO when full page is cached', () async {
      final dao = FakeBreathSessionDao();
      final sessions = _makeSessions(10);
      await dao.saveSessions(sessions);

      final api = FakeBreathSessionApi();
      final repo = _makeRepo(dao: dao, api: api);

      final results = await repo.fetch(0, 10);

      expect(results.sessions.length, 10);
      expect(api.lastFetchPage, isNull); // API not called
    });

    test('returns correct page slice from DAO (page 1)', () async {
      final dao = FakeBreathSessionDao();
      await dao.saveSessions(_makeSessions(100));

      final api = FakeBreathSessionApi();
      final repo = _makeRepo(dao: dao, api: api);

      final page0 = await repo.fetch(0, 50);
      final page1 = await repo.fetch(1, 50);

      expect(page0.sessions.length, 50);
      expect(page1.sessions.length, 50);
      expect(page0.sessions.first.id, 's1');
      expect(page1.sessions.first.id, 's51');
      expect(api.lastFetchPage, isNull); // API not called
    });

    test('falls back to API when DAO page is incomplete (partial cache)', () async {
      // 30 items in DAO, fetching page 0 with pageSize=50 → DAO returns 30 < 50 → API called
      final dao = FakeBreathSessionDao();
      await dao.saveSessions(_makeSessions(30));

      final apiSessions = _makeSessions(30);
      final api = FakeBreathSessionApi(sessions: apiSessions);
      final repo = _makeRepo(dao: dao, api: api);

      final results = await repo.fetch(0, 50);

      expect(api.lastFetchPage, 1); // API was called with 1-based page
      expect(results.sessions.length, 30);
    });
  });

  group('fetch — API fallback', () {
    test('fetches from API and caches when DAO page is empty', () async {
      final dao = FakeBreathSessionDao();
      final apiSessions = _makeSessions(50);
      final api = FakeBreathSessionApi(sessions: apiSessions);
      final repo = _makeRepo(dao: dao, api: api);

      final results = await repo.fetch(0, 50);

      expect(results.sessions.length, 50);
      // Should pass page=1 to API (0-based → 1-based conversion)
      expect(api.lastFetchPage, 1);

      // Cached in DAO
      final cached = await dao.getSessions();
      expect(cached.length, 50);
    });

    test('passes correct 1-based page to API for page 1', () async {
      final dao = FakeBreathSessionDao();
      // Seed only first page in DAO so page 1 triggers API call
      await dao.saveSessions(_makeSessions(50));

      final apiSessions = _makeSessions(50).map((s) => _makeSession('api-${s.id}')).toList();
      final api = FakeBreathSessionApi(sessions: apiSessions);
      final repo = _makeRepo(dao: dao, api: api);

      await repo.fetch(1, 50);

      expect(api.lastFetchPage, 2); // internal page=1 → API page=2
    });

    test('calls API for page 1 when DAO has partial data at that offset', () async {
      // 75 items in DAO, fetching page 1 (offset=50) with pageSize=50
      // DAO returns 25 items → less than pageSize → goes to API (page=2)
      final dao = FakeBreathSessionDao();
      await dao.saveSessions(_makeSessions(75));

      // API has 25 items for page 2
      final api = FakeBreathSessionApi(sessions: _makeSessions(50)); // full 50 so page 2 = items 51-75 of api
      final repo = _makeRepo(dao: dao, api: api);

      final results = await repo.fetch(1, 50);

      expect(api.lastFetchPage, 2);
      expect(results.sessions.length, lessThanOrEqualTo(50));
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
