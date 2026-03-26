import 'package:mind/Core/Api/HttpClient.dart';
import 'package:mind/User/IAuthApi.dart';
import 'package:mind/Core/Api/Models/GoogleAuthRequest.dart';
import 'package:mind/Core/Api/Models/SendCodeRequest.dart';
import 'package:mind/Core/Api/Models/VerifyCodeRequest.dart';
import 'package:mind/User/Models/User.dart';

class AuthApi implements IAuthApi {
  final HttpClient _http;

  AuthApi(this._http);

  @override
  Future<void> sendCode({required String email, required String locale}) async {
    await _http.post('/auth/send-code', data: SendCodeRequest(email: email, language: locale).toJson());
  }

  @override
  Future<User> verifyCode({required String email, required String code, String? language}) async {
    final response = await _http.post('/auth/verify-code', data: VerifyCodeRequest(email: email, code: code, language: language).toJson());

    final authHeader = response.headers.value('Authorization');
    if (authHeader != null) {
      final token = authHeader.replaceFirst('Bearer ', '');
      await _http.saveToken(token);
    }

    return User.fromJson(response.data);
  }

  @override
  Future<User> googleAuth({required String serverAuthCode, String? language, String? redirectUri}) async {
    final response = await _http.post('/auth/google', data: GoogleAuthRequest(serverAuthCode: serverAuthCode, language: language, redirectUri: redirectUri).toJson());

    final authHeader = response.headers.value('Authorization');
    if (authHeader != null) {
      final token = authHeader.replaceFirst('Bearer ', '');
      await _http.saveToken(token);
    }

    return User.fromJson(response.data);
  }

  @override
  Future<void> logout() async {
    await _http.post('/auth/logout', data: {});
    await _http.clearToken();
  }

  @override
  Future<void> clearToken() async {
    await _http.clearToken();
  }
}
