import 'package:mind/BreathModule/Models/BreathSession.dart';

abstract class IBreathSessionApi {
  Future<void> save(BreathSession session);
  Future<void> delete(String sessionId);
  Future<BreathSession> fetchById(String id);
  Future<List<BreathSession>> fetchAll(int page, int pageSize);
}
