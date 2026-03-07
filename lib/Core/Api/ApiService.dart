import 'dart:developer';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mind/Core/Api/IAuthApi.dart';
import 'package:mind/BreathModule/Models/BreathSession.dart';
import 'package:mind/BreathModule/Models/BreathSessionsListResponse.dart';
import 'package:mind/Core/Api/AuthInterceptor.dart';
import 'package:mind/Core/Api/Models/ApiExeption.dart';
import 'package:mind/Core/Api/Models/GoogleAuthRequest.dart';
import 'package:mind/Core/Api/Models/SendCodeRequest.dart';
import 'package:mind/Core/Api/Models/VerifyCodeRequest.dart';
import '../Environment.dart';

import 'package:mind/User/Models/User.dart';
import 'package:dio/dio.dart';

class ApiService implements IAuthApi {
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

  @override
  Future<void> sendCode(SendCodeRequest request) async {
    try {
      await _dio.post('/auth/send-code', data: request.toJson());
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<User> verifyCode(VerifyCodeRequest request) async {
    try {
      final response = await _dio.post(
        '/auth/verify-code',
        data: request.toJson(),
      );

      final authHeader = response.headers.value('Authorization');
      if (authHeader != null) {
        final token = authHeader.replaceFirst('Bearer ', '');
        await _storage.write(key: _tokenKey, value: token);
      }

      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<User> googleAuth(GoogleAuthRequest request) async {
    try {
      final response = await _dio.post(
        '/auth/google',
        data: request.toJson(),
      );

      final authHeader = response.headers.value('Authorization');
      if (authHeader != null) {
        final token = authHeader.replaceFirst('Bearer ', '');
        await _storage.write(key: _tokenKey, value: token);
      }

      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
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

  @override
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

      log('[ApiService] HTTP ${e.response?.statusCode} ${e.requestOptions.method} ${e.requestOptions.path} — $message', name: 'ApiService', error: e);

      return ApiException(
        message: message,
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    } else {
      log('[ApiService] ${e.type} ${e.requestOptions.method} ${e.requestOptions.path} — ${e.message}', name: 'ApiService', error: e);

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

      return BreathSession.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<List<BreathSession>> fetchBreathSessions(int page, int pageSize) async {
    try {
      final response = await _dio.get('/breath_sessions/list?page=$page&pageSize=$pageSize');

      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      final sessions = BreathSessionsListResponse.fromJson(data).data;
      return sessions;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
}
