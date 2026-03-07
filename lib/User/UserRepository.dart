import 'dart:developer';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mind/Core/Api/ApiService.dart';
import 'package:mind/Core/Api/Models/GoogleAuthRequest.dart';
import 'package:mind/Core/Api/Models/SendCodeRequest.dart';
import 'package:mind/Core/Api/Models/VerifyCodeRequest.dart';
import 'package:mind/Core/Database/Database.dart';
import 'package:mind/User/Models/GoogleSignInCanceledException.dart';
import 'Models/User.dart';

class UserRepository {
  final Database _db;
  final ApiService _api;
  final FlutterSecureStorage _storage;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static const String _pendingSignInEmailKey = 'pendingSignInEmail';

  UserRepository({required Database db, required ApiService api})
      : _api = api,
        _db = db,
        _storage = const FlutterSecureStorage();

  Future<User?> _getUser() async {
    return await _db.userDao.getUser();
  }

  Future<void> _saveUser(User user) async {
    await _db.userDao.saveUser(user);
  }

  Future<void> _deleteUser(String userId) async {
    await _db.userDao.deleteUser(userId);
  }

  Future<void> _replaceGuestWithUser(User user) async {
    final existingUser = await _getUser();
    if (existingUser != null && existingUser.isGuest) {
      await _deleteUser(existingUser.id);
    }
    await _saveUser(user);
  }

  Future<User> loadUser() async {
    final existingUser = await _getUser();

    if (existingUser != null) {
      return existingUser;
    }

    final guest = User.guest();
    await _saveUser(guest);
    return guest;
  }

  Future<void> sendPasswordlessSignInLink(String email) async {
    log('[UserRepository] sendPasswordlessSignInLink: email=$email');
    await _api.sendCode(SendCodeRequest(email: email));
    await _storage.write(key: _pendingSignInEmailKey, value: email);
  }

  Future<User> completePasswordlessSignIn(String code) async {
    final email = await _storage.read(key: _pendingSignInEmailKey);
    if (email == null || email.isEmpty) {
      throw Exception('No pending email found');
    }
    log('[UserRepository] completePasswordlessSignIn: email=$email');
    final user = await _api.verifyCode(VerifyCodeRequest(email: email, code: code));
    await _replaceGuestWithUser(user);
    await _storage.delete(key: _pendingSignInEmailKey);
    return user;
  }

  /// Phase 1: Shows the native Google account picker dialog.
  Future<GoogleSignInAccount> pickGoogleAccount() async {
    log('[UserRepository] pickGoogleAccount: showing Google account picker');
    try {
      return await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw GoogleSignInCanceledException();
      }
      rethrow;
    }
  }

  /// Phase 2: Authenticate with the API using the Google account.
  Future<User> authenticateWithGoogle(GoogleSignInAccount googleUser) async {
    log('[UserRepository] authenticateWithGoogle: requesting server auth code');
    final serverAuth = await googleUser.authorizationClient.authorizeServer([]);
    if (serverAuth == null) {
      throw Exception(
        'Google Sign-In did not return a serverAuthCode. Try signing in again.',
      );
    }

    log('[UserRepository] authenticateWithGoogle: exchanging serverAuthCode with API');
    final request = GoogleAuthRequest(serverAuthCode: serverAuth.serverAuthCode);
    final user = await _api.googleAuth(request);
    await _replaceGuestWithUser(user);
    return user;
  }

  Future<User> logout(User currentUser) async {
    await _api.logout(currentUser);
    return await clearSession(currentUser);
  }

  Future<User> clearSession(User currentUser) async {
    await _googleSignIn.signOut();
    await _api.clearToken();

    await _deleteUser(currentUser.id);

    final newGuest = User.guest();
    await _saveUser(newGuest);

    return newGuest;
  }
}
