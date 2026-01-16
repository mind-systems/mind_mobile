import 'package:mind/Core/ApiService.dart';
import 'package:mind/Core/Database.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';

class BreathSessionRepository {
  final Database _db;
  final ApiService _api;

  BreathSessionRepository({required Database db, required ApiService api})
      : _db = db,
        _api = api;

  Future<List<BreathSession>> fetch(int page, int pageSize) async {
    // from repo if empty api
    final sessions = await _db.breathSessionDao.getSessions();
    if (sessions.isEmpty) {
      final sessions = await _api.fetchBreathSessions(page, pageSize);
      await _db.breathSessionDao.saveSessions(sessions);
      return sessions;
    }
    return sessions;
  }

  Future<void> save(BreathSession session) async {
    await _api.saveBreathSession(session);
    await _db.breathSessionDao.saveSession(session);
  }

  Future<void> delete(String id) async {
    await _api.deleteBreathSession(id);
    await _db.breathSessionDao.deleteSession(id);
  }
}
