import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/Core/Api/AuthInterceptor.dart';
import 'package:mind/Core/Api/Models/ApiExeption.dart';
import 'package:mind/User/Models/AuthRequest.dart';
import '../Environment.dart';

import 'package:mind/User/Models/User.dart';
import 'package:dio/dio.dart';

class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'jwt_token';

  ApiService({required AuthInterceptor authInterceptor})
      : _storage = const FlutterSecureStorage() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Environment.instance.apiBaseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    _dio.interceptors.add(authInterceptor);
  }

  Future<void> updateUser(User user) async {}

  Future<User> authenticate(AuthRequest authRequest) async {
    try {
      final path = '/auth/authenticate';
      final data = authRequest.toJson();
      final response = await _dio.post(path, data: data);

      if (response.statusCode == 200) {
        final authHeader = response.headers.value('Authorization');
        if (authHeader != null) {
          final token = authHeader.replaceFirst('Bearer ', '');
          await _storage.write(key: _tokenKey, value: token);
        }

        return User.fromJson(response.data);
      }

      throw ApiException(
        message: 'Unexpected status code',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> logout(User user) async {
    try {
      var path = '/auth/logout';
      var data = {'id': user.id};
      final _ = await _dio.post(path, data: data);
      await clearToken();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  ApiException _handleDioError(DioException e) {
    if (e.response != null) {
      final message =
          e.response?.data['message'] ??
          e.response?.data['error'] ??
          e.message ??
          'Unknown error';

      return ApiException(
        message: message,
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    } else {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ApiException(message: 'Connection timeout');
        case DioExceptionType.connectionError:
          return ApiException(message: 'No internet connection');
        default:
          return ApiException(message: e.message ?? 'Network error');
      }
    }
  }
}

extension BreathSessionApi on ApiService {
  Future<void> saveBreathSession(BreathSession session) async {
    try {
      await _dio.post(
        '/breath_sessions',
        data: session.toJson(),
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> deleteBreathSession(String sessionId) async {
    try {
      await _dio.delete(
        '/breath_sessions/$sessionId',
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<BreathSession> fetchBreathSession(String id) async {
    try {
      final response = await _dio.get('/breath_sessions/$id');

      if (response.statusCode == 200) {
        return BreathSession.fromJson(response.data as Map<String, dynamic>);
      }

      throw ApiException(
        message: 'Unexpected status code',
        statusCode: response.statusCode,
        data: response.data,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<List<BreathSession>> fetchBreathSessions(int page, int pageSize) async {
    try {
      final response = await _dio.get('/breath_sessions/list?page=$page&pageSize=$pageSize');

      if (response.statusCode == 200) {
        final List data = response.data as List<dynamic>;
        return data.map((raw) => BreathSession.fromJson(raw as Map<String, dynamic>)).toList();
      } else {
        throw ApiException(
          message: 'Unexpected status code',
          statusCode: response.statusCode,
          data: response.data,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
}
