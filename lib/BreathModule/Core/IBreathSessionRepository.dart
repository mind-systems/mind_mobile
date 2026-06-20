import 'package:mind/BreathModule/Models/BreathSession.dart';

abstract interface class IBreathSessionRepository {
  Future<BreathSession> fetchById(String id);
  Future<List<BreathSession>> localSessions();

  /// Full-mirror write-through sync: pages through all server sessions and
  /// upserts each page into the local Drift store. Returns void — callers
  /// re-read the local mirror via [localSessions] after this completes.
  Future<void> refresh(int pageSize);

  Future<BreathSession> create(BreathSession session);
  Future<BreathSession> update(BreathSession session);
  Future<void> delete(String id);
  Future<void> starSession(String id, {required bool starred});
  Future<void> deleteAll();
}
