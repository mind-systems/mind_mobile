import 'package:mind/Core/Models/ApiExeption.dart';
import 'package:mind/User/Models/AuthRequest.dart';
import 'Environment.dart';

import 'package:mind/User/Models/User.dart';
import 'package:dio/dio.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Environment.instance.apiBaseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  Future<void> updateUser(User user) async {}

  Future<User> authenticate(AuthRequest authRequest) async {
    throw ApiException(message: 'no api yet');

    // try {
    //   final response = await _dio.post(
    //     '/auth/authenticate',
    //     data: authRequest.toJson(),
    //   );
    //
    //   if (response.statusCode == 200) {
    //     return User.fromJson(response.data);
    //   }
    //
    //   throw ApiException(message: 'Unexpected status code', statusCode: response.statusCode,);
    // } on DioException catch (e) {
    //   throw _handleDioError(e);
    // }
  }

  Future<void> logout(User user) async {
    try {
      var path = '/auth/logout';
      var data = {'id': user.id};
      final _ = await _dio.post(path, data: data);
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
