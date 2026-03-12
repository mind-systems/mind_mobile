import 'package:mind/BreathModule/Core/IBreathSessionApi.dart';
import 'package:mind/Core/Api/Models/SaveBreathSessionRequest.dart';
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
    final offset = page * pageSize;
    final daoPage = await _dao.getSessions(limit: pageSize, offset: offset);

    if (daoPage.length == pageSize) {
      return daoPage;
    }

    // DAO вернул меньше чем pageSize — идём в API
    // API использует 1-based нумерацию страниц
    final apiSessions = await _api.fetchAll(page + 1, pageSize);
    await _dao.saveSessions(apiSessions);
    return apiSessions;
  }

  Future<BreathSession> create(BreathSession session) async {
    final request = SaveBreathSessionRequest(
      description: session.description,
      exercises: session.exercises,
      shared: session.shared,
    );
    final saved = await _api.create(request);
    await _dao.saveSession(saved);
    return saved;
  }

  Future<BreathSession> update(BreathSession session) async {
    final request = SaveBreathSessionRequest(
      description: session.description,
      exercises: session.exercises,
      shared: session.shared,
    );
    final saved = await _api.update(session.id, request);
    await _dao.saveSession(saved);
    return saved;
  }

  Future<void> delete(String id) async {
    await _api.delete(id);
    await _dao.deleteSession(id);
  }

  Future<void> deleteAll() async {
    await _dao.deleteAllSessions();
  }
}
