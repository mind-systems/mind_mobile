import 'package:mind/Core/Api/IAuthApi.dart';
import 'package:mind/Core/Api/Models/GoogleAuthRequest.dart';
import 'package:mind/Core/Api/Models/SendCodeRequest.dart';
import 'package:mind/Core/Api/Models/VerifyCodeRequest.dart';
import 'package:mind/Core/Database/IUserDao.dart';
import 'package:mind/User/Infrastructure/IGoogleAuthProvider.dart';
import 'package:mind/User/Infrastructure/ISecureStorage.dart';
import 'Models/User.dart';

class UserRepository {
  final IUserDao _userDao;
  final IAuthApi _api;
  final IGoogleAuthProvider _google;
  final ISecureStorage _storage;

  static const String _pendingSignInEmailKey = 'pendingSignInEmail';

  UserRepository({
    required IUserDao userDao,
    required IAuthApi api,
    required IGoogleAuthProvider google,
    required ISecureStorage storage,
  })  : _userDao = userDao,
        _api = api,
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

  Future<void> sendPasswordlessSignInLink(String email) async {
    await _api.sendCode(SendCodeRequest(email: email));
    await _storage.write(_pendingSignInEmailKey, email);
  }

  Future<User> completePasswordlessSignIn(String code) async {
    final email = await _storage.read(_pendingSignInEmailKey);
    if (email == null || email.isEmpty) {
      throw Exception('No pending email found');
    }
    final user = await _api.verifyCode(VerifyCodeRequest(email: email, code: code));
    await _replaceGuestWithUser(user);
    await _storage.delete(_pendingSignInEmailKey);
    return user;
  }

  /// Phase 1: shows the native Google account picker. Throws
  /// [GoogleSignInCanceledException] if the user dismisses the dialog.
  Future<void> pickGoogleAccount() => _google.pickGoogleAccount();

  /// Phase 2: exchanges the picked account for a server auth code and
  /// authenticates with the backend.
  Future<User> authenticateWithGoogle() async {
    final serverAuthCode = await _google.getServerAuthCode();
    final request = GoogleAuthRequest(serverAuthCode: serverAuthCode);
    final user = await _api.googleAuth(request);
    await _replaceGuestWithUser(user);
    return user;
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
