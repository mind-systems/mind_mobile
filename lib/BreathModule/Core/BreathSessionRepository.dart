import 'package:mind/BreathModule/Core/IBreathSessionApi.dart';
import 'package:mind/BreathModule/Core/IBreathSessionRepository.dart';
import 'package:mind/Core/Api/Models/SaveBreathSessionRequest.dart';
import 'package:mind/Core/Api/Models/StarSessionRequest.dart';
import 'package:mind/Core/Database/IBreathSessionDao.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/BreathSessionsListResponse.dart';

class BreathSessionRepository implements IBreathSessionRepository {
  final IBreathSessionDao _dao;
  final IBreathSessionApi _api;

  BreathSessionRepository({required IBreathSessionDao dao, required IBreathSessionApi api})
      : _dao = dao,
        _api = api;

  @override
  Future<BreathSession> fetchById(String id) async {
    final session = await _dao.getSessionById(id);
    if (session != null) {
      return session;
    }
    return await _api.fetchById(id);
  }

  @override
  Future<List<BreathSession>> localSessions() async {
    return await _dao.getSessions();
  }

  @override
  Future<({List<BreathSessionListEntry> entries, String? nextCursor})> refresh(int pageSize) async {
    final response = await _api.fetchPage(null, pageSize);
    // Upsert — do NOT deleteAllSessions; detail/getById rely on cached rows
    await _dao.saveSessions(response.entries.map((e) => e.session).toList());
    return (entries: response.entries, nextCursor: response.nextCursor);
  }

  @override
  Future<({List<BreathSessionListEntry> entries, String? nextCursor})> fetch(String? cursor, int pageSize) async {
    final response = await _api.fetchPage(cursor, pageSize);
    await _dao.saveSessions(response.entries.map((e) => e.session).toList());
    return (entries: response.entries, nextCursor: response.nextCursor);
  }

  @override
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

  @override
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

  @override
  Future<void> delete(String id) async {
    await _api.delete(id);
    await _dao.deleteSession(id);
  }

  @override
  Future<void> starSession(String id, {required bool starred}) async {
    await _api.starSession(StarSessionRequest(id: id, starred: starred));
    final session = await _dao.getSessionById(id);
    if (session != null) {
      await _dao.saveSession(session.copyWith(isStarred: starred));
    }
  }

  @override
  Future<void> deleteAll() async {
    await _dao.deleteAllSessions();
  }
}
