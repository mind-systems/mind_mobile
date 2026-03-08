import 'package:mind/BreathModule/Core/IBreathSessionApi.dart';
import 'package:mind/Core/Database/IBreathSessionDao.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';

class BreathSessionRepository {
  final IBreathSessionDao _dao;
  final IBreathSessionApi _api;

  BreathSessionRepository({required IBreathSessionDao dao, required IBreathSessionApi api})
      : _dao = dao,
        _api = api;

  Future<BreathSession> fetchById(String id) async {
    final session = await _dao.getSessionById(id);
    if (session != null) {
      return session;
    }
    return await _api.fetchById(id);
  }

  Future<List<BreathSession>> fetch(int page, int pageSize) async {
    // from repo if empty api
    final sessions = await _dao.getSessions();
    if (sessions.isEmpty) {
      final sessions = await _api.fetchAll(page, pageSize);
      await _dao.saveSessions(sessions);
      return sessions;
    }
    return sessions;
  }

  Future<void> save(BreathSession session) async {
    await _api.save(session);
    await _dao.saveSession(session);
  }

  Future<void> delete(String id) async {
    await _api.delete(id);
    await _dao.deleteSession(id);
  }

  Future<void> deleteAll() async {
    await _dao.deleteAllSessions();
  }
}
