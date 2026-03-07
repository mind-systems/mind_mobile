import 'package:dio/dio.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/BreathSessionsListResponse.dart';
import 'package:mind/Core/Api/HttpClient.dart';
import 'package:mind/Core/Api/IBreathSessionApi.dart';

class BreathSessionApi implements IBreathSessionApi {
  final HttpClient _http;

  BreathSessionApi(this._http);

  @override
  Future<void> save(BreathSession session) async {
    try {
      await _http.dio.post('/breath_sessions', data: session.toJson());
    } on DioException catch (e) {
      throw _http.handleDioError(e);
    }
  }

  @override
  Future<void> delete(String sessionId) async {
    try {
      await _http.dio.delete('/breath_sessions/$sessionId');
    } on DioException catch (e) {
      throw _http.handleDioError(e);
    }
  }

  @override
  Future<BreathSession> fetchById(String id) async {
    try {
      final response = await _http.dio.get('/breath_sessions/$id');
      return BreathSession.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _http.handleDioError(e);
    }
  }

  @override
  Future<List<BreathSession>> fetchAll(int page, int pageSize) async {
    try {
      final response = await _http.dio.get('/breath_sessions/list?page=$page&pageSize=$pageSize');
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      return BreathSessionsListResponse.fromJson(data).data;
    } on DioException catch (e) {
      throw _http.handleDioError(e);
    }
  }
}
