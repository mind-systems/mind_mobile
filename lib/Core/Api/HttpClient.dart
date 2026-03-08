import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mind/Core/Api/AuthInterceptor.dart';
import 'package:mind/Core/Api/Models/ApiExeption.dart';
import 'package:mind/Core/Environment.dart';

class HttpClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'jwt_token';

  HttpClient({required AuthInterceptor authInterceptor})
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

  Future<Response> get(String path) async {
    try {
      return await _dio.get(path);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> post(String path, {Object? data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
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

      log('[HttpClient] HTTP ${e.response?.statusCode} ${e.requestOptions.method} ${e.requestOptions.path} — $message', name: 'HttpClient', error: e);

      return ApiException(
        message: message,
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    } else {
      log('[HttpClient] ${e.type} ${e.requestOptions.method} ${e.requestOptions.path} — ${e.message}', name: 'HttpClient', error: e);

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
