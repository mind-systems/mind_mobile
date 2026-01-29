import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mind/User/LogoutNotifier.dart';

class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final LogoutNotifier _logoutNotifier;


  static const String _tokenKey = 'jwt_token';

  AuthInterceptor({
    required FlutterSecureStorage storage,
    required LogoutNotifier logoutNotifier,
  }) : _storage = storage, _logoutNotifier = logoutNotifier;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: _tokenKey);

    if (token != null && options.path != '/auth/authenticate') {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      _logoutNotifier.triggerLogout();
    }

    handler.reject(err);
  }
}
