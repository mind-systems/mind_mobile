import 'package:mind/Core/Api/Models/GoogleAuthRequest.dart';
import 'package:mind/Core/Api/Models/SendCodeRequest.dart';
import 'package:mind/Core/Api/Models/VerifyCodeRequest.dart';
import 'package:mind/User/Models/User.dart';

abstract class IAuthApi {
  Future<void> sendCode(SendCodeRequest request);
  Future<User> verifyCode(VerifyCodeRequest request);
  Future<User> googleAuth(GoogleAuthRequest request);
  Future<void> logout(User user);
  Future<void> clearToken();
}
