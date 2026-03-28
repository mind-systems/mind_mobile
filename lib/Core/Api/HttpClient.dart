import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:mind/Core/Api/Models/ApiExeption.dart';
import 'package:mind/Core/Environment.dart';

class HttpClient {
  late final Dio _dio;

  HttpClient({required List<Interceptor> interceptors}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: Environment.instance.apiBaseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    _dio.interceptors.addAll(interceptors);
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
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

  Future<Response> patch(String path, {Object? data}) async {
    try {
      return await _dio.patch(path, data: data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> put(String path, {Object? data}) async {
    try {
      return await _dio.put(path, data: data);
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
