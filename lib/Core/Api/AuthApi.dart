import 'package:mind/Core/Api/HttpClient.dart';
import 'package:mind/Core/Api/IAuthApi.dart';
import 'package:mind/Core/Api/Models/GoogleAuthRequest.dart';
import 'package:mind/Core/Api/Models/SendCodeRequest.dart';
import 'package:mind/Core/Api/Models/VerifyCodeRequest.dart';
import 'package:mind/User/Models/User.dart';

class AuthApi implements IAuthApi {
  final HttpClient _http;

  AuthApi(this._http);

  @override
  Future<void> sendCode(SendCodeRequest request) async {
    await _http.post('/auth/send-code', data: request.toJson());
  }

  @override
  Future<User> verifyCode(VerifyCodeRequest request) async {
    final response = await _http.post('/auth/verify-code', data: request.toJson());

    final authHeader = response.headers.value('Authorization');
    if (authHeader != null) {
      final token = authHeader.replaceFirst('Bearer ', '');
      await _http.saveToken(token);
    }

    return User.fromJson(response.data);
  }

  @override
  Future<User> googleAuth(GoogleAuthRequest request) async {
    final response = await _http.post('/auth/google', data: request.toJson());

    final authHeader = response.headers.value('Authorization');
    if (authHeader != null) {
      final token = authHeader.replaceFirst('Bearer ', '');
      await _http.saveToken(token);
    }

    return User.fromJson(response.data);
  }

  @override
  Future<void> logout(User user) async {
    await _http.post('/auth/logout', data: {'id': user.id});
    await _http.clearToken();
  }

  @override
  Future<void> clearToken() async {
    await _http.clearToken();
  }
}
