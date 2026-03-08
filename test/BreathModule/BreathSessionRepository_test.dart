import 'package:flutter_test/flutter_test.dart';
import 'package:mind/BreathModule/Core/BreathSessionRepository.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Core/IBreathSessionApi.dart';
import 'package:mind/Core/Database/IBreathSessionDao.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeBreathSessionDao implements IBreathSessionDao {
  final List<BreathSession> _sessions = [];

  @override
  Future<List<BreathSession>> getSessions() async => List.unmodifiable(_sessions);

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

  bool saveCalled = false;
  String? lastSavedId;
  bool deleteCalled = false;
  String? lastDeletedId;

  FakeBreathSessionApi({List<BreathSession>? sessions})
      : _sessions = sessions ?? [];

  @override
  Future<void> save(BreathSession session) async {
    saveCalled = true;
    lastSavedId = session.id;
    _sessions.add(session);
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
  Future<List<BreathSession>> fetchAll(int page, int pageSize) async {
    return List.unmodifiable(_sessions);
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

  group('fetch', () {
    test('returns DB sessions when non-empty', () async {
      final dao = FakeBreathSessionDao();
      final session = _makeSession('s3');
      await dao.saveSession(session);

      final api = FakeBreathSessionApi();
      final repo = _makeRepo(dao: dao, api: api);

      final results = await repo.fetch(1, 10);

      expect(results.length, 1);
      expect(results.first.id, 's3');
    });

    test('fetches from API and caches when DB empty', () async {
      final dao = FakeBreathSessionDao();
      final session = _makeSession('s4');
      final api = FakeBreathSessionApi(sessions: [session]);
      final repo = _makeRepo(dao: dao, api: api);

      final results = await repo.fetch(1, 10);

      expect(results.length, 1);
      expect(results.first.id, 's4');

      // Verify cached in DAO
      final cached = await dao.getSessions();
      expect(cached.length, 1);
      expect(cached.first.id, 's4');
    });
  });

  group('save', () {
    test('calls api.save and persists to DAO', () async {
      final dao = FakeBreathSessionDao();
      final api = FakeBreathSessionApi();
      final repo = _makeRepo(dao: dao, api: api);
      final session = _makeSession('s5');

      await repo.save(session);

      expect(api.saveCalled, true);
      expect(api.lastSavedId, 's5');

      final stored = await dao.getSessionById('s5');
      expect(stored, isNotNull);
      expect(stored!.id, 's5');
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
