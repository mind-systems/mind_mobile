import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/BreathSessionsListResponse.dart';

abstract interface class IBreathSessionRepository {
  Future<BreathSession> fetchById(String id);
  Future<({List<BreathSessionListEntry> entries, String? nextCursor})> refresh(int pageSize);
  Future<({List<BreathSessionListEntry> entries, String? nextCursor})> fetch(String? cursor, int pageSize);
  Future<BreathSession> create(BreathSession session);
  Future<BreathSession> update(BreathSession session);
  Future<void> delete(String id);
  Future<void> starSession(String id, {required bool starred});
  Future<void> deleteAll();
}
