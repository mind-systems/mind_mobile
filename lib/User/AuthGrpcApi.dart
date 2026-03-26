import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mind/Core/Grpc/generated/auth.pb.dart' as proto;
import 'package:mind/Core/Grpc/generated/auth.pbgrpc.dart';
import 'package:mind/User/IAuthApi.dart';
import 'package:mind/User/Models/User.dart';

class AuthGrpcApi implements IAuthApi {
  final AuthServiceClient _authService;
  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'jwt_token';

  AuthGrpcApi(this._authService, this._storage);

  @override
  Future<void> sendCode({required String email, required String locale}) async {
    await _authService.sendCode(proto.SendCodeRequest(email: email, locale: locale));
  }

  @override
  Future<User> verifyCode({required String email, required String code, String? language}) async {
    final response = await _authService.verifyCode(proto.VerifyCodeRequest(email: email, code: code, language: language));
    await _storage.write(key: _tokenKey, value: response.accessToken);
    return _mapUser(response.user);
  }

  @override
  Future<User> googleAuth({required String serverAuthCode, String? language, String? redirectUri}) async {
    final response = await _authService.googleAuth(proto.GoogleAuthRequest(serverAuthCode: serverAuthCode, language: language, redirectUri: redirectUri));
    await _storage.write(key: _tokenKey, value: response.accessToken);
    return _mapUser(response.user);
  }

  @override
  Future<void> logout() async {
    await _authService.logout(proto.LogoutRequest());
    await _storage.delete(key: _tokenKey);
  }

  @override
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  User _mapUser(proto.UserDto userDto) {
    return User(id: userDto.id, email: userDto.email, name: userDto.name, language: userDto.language, isGuest: false);
  }
}
