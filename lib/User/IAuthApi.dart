import 'package:mind/User/Models/User.dart';

abstract class IAuthApi {
  Future<void> sendCode({required String email, required String locale});
  Future<User> verifyCode({required String email, required String code, String? language});
  Future<User> googleAuth({required String serverAuthCode, String? language, String? redirectUri});
  Future<void> logout();
  Future<void> clearToken();
}
