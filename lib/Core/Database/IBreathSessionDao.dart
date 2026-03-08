import 'package:mind/BreathModule/Models/BreathSession.dart';

abstract class IBreathSessionDao {
  Future<List<BreathSession>> getSessions({int? limit, int? offset});
  Future<BreathSession?> getSessionById(String id);
  Future<void> saveSession(BreathSession session);
  Future<void> saveSessions(List<BreathSession> sessions);
  Future<void> deleteSession(String id);
  Future<void> deleteAllSessions();
}
