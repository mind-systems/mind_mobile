import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/BreathSessionsListResponse.dart';
import 'package:mind/Core/Api/Models/SaveBreathSessionRequest.dart';
import 'package:mind/Core/Api/Models/StarSessionRequest.dart';

abstract class IBreathSessionApi {
  Future<BreathSession> create(SaveBreathSessionRequest request);
  Future<BreathSession> update(String id, SaveBreathSessionRequest request);
  Future<void> delete(String sessionId);
  Future<BreathSession> fetchById(String id);
  Future<BreathSessionsListResponse> fetchAll(int page, int pageSize);
  Future<void> starSession(StarSessionRequest request);
}
