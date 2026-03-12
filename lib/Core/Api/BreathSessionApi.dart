import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/BreathSessionsListResponse.dart';
import 'package:mind/Core/Api/HttpClient.dart';
import 'package:mind/Core/Api/Models/SaveBreathSessionRequest.dart';
import 'package:mind/BreathModule/Core/IBreathSessionApi.dart';

class BreathSessionApi implements IBreathSessionApi {
  final HttpClient _http;

  BreathSessionApi(this._http);

  @override
  Future<BreathSession> create(SaveBreathSessionRequest request) async {
    final response = await _http.post('/breath_sessions', data: request.toJson());
    return BreathSession.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<BreathSession> update(String id, SaveBreathSessionRequest request) async {
    final response = await _http.put('/breath_sessions/$id', data: request.toJson());
    return BreathSession.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> delete(String sessionId) async {
    await _http.delete('/breath_sessions/$sessionId');
  }

  @override
  Future<BreathSession> fetchById(String id) async {
    final response = await _http.get('/breath_sessions/$id');
    return BreathSession.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<BreathSession>> fetchAll(int page, int pageSize) async {
    final response = await _http.get('/breath_sessions/list?page=$page&pageSize=$pageSize');
    final Map<String, dynamic> data = response.data as Map<String, dynamic>;
    return BreathSessionsListResponse.fromJson(data).data;
  }
}
