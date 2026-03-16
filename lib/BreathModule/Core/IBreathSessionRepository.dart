import 'package:mind/BreathModule/Models/BreathSession.dart';

abstract interface class IBreathSessionRepository {
  Future<BreathSession> fetchById(String id);
  Future<({List<BreathSession> sessions, bool hasMore})> refresh(int pageSize);
  Future<({List<BreathSession> sessions, bool hasMore})> fetch(int page, int pageSize);
  Future<BreathSession> create(BreathSession session);
  Future<BreathSession> update(BreathSession session);
  Future<void> delete(String id);
  Future<void> starSession(String id, {required bool starred});
  Future<void> deleteAll();
}
