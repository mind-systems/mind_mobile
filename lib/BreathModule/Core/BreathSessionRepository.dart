import 'package:mind/Core/Api/IBreathSessionApi.dart';
import 'package:mind/Core/Database/Database.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';

class BreathSessionRepository {
  final Database _db;
  final IBreathSessionApi _api;

  BreathSessionRepository({required Database db, required IBreathSessionApi api})
      : _db = db,
        _api = api;

  Future<BreathSession> fetchById(String id) async {
    final session = await _db.breathSessionDao.getSessionById(id);
    if (session != null) {
      return session;
    }
    return await _api.fetchById(id);
  }

  Future<List<BreathSession>> fetch(int page, int pageSize) async {
    // from repo if empty api
    final sessions = await _db.breathSessionDao.getSessions();
    if (sessions.isEmpty) {
      final sessions = await _api.fetchAll(page, pageSize);
      await _db.breathSessionDao.saveSessions(sessions);
      return sessions;
    }
    return sessions;
  }

  Future<void> save(BreathSession session) async {
    await _api.save(session);
    await _db.breathSessionDao.saveSession(session);
  }

  Future<void> delete(String id) async {
    await _api.delete(id);
    await _db.breathSessionDao.deleteSession(id);
  }

  Future<void> deleteAll() async {
    await _db.breathSessionDao.deleteAllSessions();
  }
}
