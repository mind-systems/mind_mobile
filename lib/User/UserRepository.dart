import 'package:mind/User/IAuthApi.dart';
import 'package:mind/User/IUserApi.dart';
import 'package:mind/Core/Api/Models/GoogleAuthRequest.dart';
import 'package:mind/Core/Api/Models/SendCodeRequest.dart';
import 'package:mind/Core/Api/Models/UpdateUserRequest.dart';
import 'package:mind/Core/Api/Models/VerifyCodeRequest.dart';
import 'package:mind/Core/Database/IUserDao.dart';
import 'package:mind/User/Infrastructure/IGoogleAuthProvider.dart';
import 'package:mind/User/Infrastructure/ISecureStorage.dart';
import 'Models/User.dart';

class UserRepository {
  final IUserDao _userDao;
  final IAuthApi _api;
  final IUserApi _userApi;
  final IGoogleAuthProvider _google;
  final ISecureStorage _storage;

  static const String _pendingSignInEmailKey = 'pendingSignInEmail';

  UserRepository({
    required IUserDao userDao,
    required IAuthApi api,
    required IUserApi userApi,
    required IGoogleAuthProvider google,
    required ISecureStorage storage,
  })  : _userDao = userDao,
        _api = api,
        _userApi = userApi,
        _google = google,
        _storage = storage;

  Future<void> _replaceGuestWithUser(User user) async {
    final existingUser = await _userDao.getUser();
    if (existingUser != null && existingUser.isGuest) {
      await _userDao.deleteUser(existingUser.id);
    }
    await _userDao.saveUser(user);
  }

  Future<User> loadUser() async {
    final existingUser = await _userDao.getUser();

    if (existingUser != null) {
      return existingUser;
    }

    final guest = User.guest();
    await _userDao.saveUser(guest);
    return guest;
  }

  Future<void> sendPasswordlessSignInLink(String email, {String language = 'en'}) async {
    await _api.sendCode(SendCodeRequest(email: email, language: language));
    await _storage.write(_pendingSignInEmailKey, email);
  }

  Future<User> completePasswordlessSignIn(String code, {String? language}) async {
    final email = await _storage.read(_pendingSignInEmailKey);
    if (email == null || email.isEmpty) {
      throw Exception('No pending email found');
    }
    final user = await _api.verifyCode(VerifyCodeRequest(email: email, code: code, language: language));
    await _replaceGuestWithUser(user);
    await _storage.delete(_pendingSignInEmailKey);
    return user;
  }

  /// Phase 1: Google OAuth — picker + consent → server auth code.
  /// Throws [GoogleSignInCanceledException] if the user dismisses the dialog.
  Future<String> getGoogleServerAuthCode() => _google.getServerAuthCode();

  /// Phase 2: sends auth code to our backend → returns User.
  Future<User> authenticateWithGoogle({required String serverAuthCode, String? language}) async {
    final request = GoogleAuthRequest(serverAuthCode: serverAuthCode, language: language);
    final user = await _api.googleAuth(request);
    await _replaceGuestWithUser(user);
    return user;
  }

  Future<void> updateLanguage(String language) async {
    await _userApi.updateUser(UpdateUserRequest(language: language));
  }

  Future<void> updateName(String name) async {
    await _userApi.updateUser(UpdateUserRequest(name: name));
  }

  Future<User> logout(User currentUser) async {
    await _api.logout(currentUser);
    return await clearSession(currentUser);
  }

  Future<User> clearSession(User currentUser) async {
    await _google.signOut();
    await _api.clearToken();

    await _userDao.deleteUser(currentUser.id);

    final newGuest = User.guest();
    await _userDao.saveUser(newGuest);

    return newGuest;
  }
}
