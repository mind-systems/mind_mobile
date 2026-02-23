import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mind/Core/Api/ApiService.dart';
import 'package:mind/Core/Database/Database.dart';
import 'package:mind/Core/Environment.dart';
import 'package:mind/User/Models/AuthRequest.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Models/User.dart';

class UserRepository {
  final Database _db;
  final ApiService _api;

  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static const String _emailForSignInKey = 'emailForSignIn';

  UserRepository({required Database db, required ApiService api}): _api = api, _db = db;

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
    final prefs = await SharedPreferences.getInstance();

    final actionCodeSettings = firebase_auth.ActionCodeSettings(
      linkDomain: Environment.instance.linkDomain,
      url: Environment.instance.deeplinkUrl,
      handleCodeInApp: true,
      iOSBundleId: Environment.instance.iosBundleId,
      androidPackageName: Environment.instance.androidPackageName,
      androidInstallApp: true,
    );

    await _firebaseAuth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: actionCodeSettings,
    );

    await prefs.setString(_emailForSignInKey, email);
    await prefs.reload();
  }

  Future<User> completePasswordlessSignIn(String emailLink) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_emailForSignInKey);

    if (email == null) {
      throw Exception('Email not found. Please try signing in again.');
    }

    final userCredential = await _firebaseAuth.signInWithEmailLink(
      email: email,
      emailLink: emailLink,
    );

    final String? idToken = await userCredential.user?.getIdToken();
    if (idToken == null) {
      throw Exception('Failed to get ID token');
    }

    final firebaseUser = userCredential.user;
    if (firebaseUser == null) {
      throw Exception('Failed to get Firebase user');
    }

    final user = User.fromFirebaseUser(firebaseUser);
    final authRequest = AuthRequest(token: idToken, user: user);
    final authenticatedUser = await _api.authenticate(authRequest);

    await _replaceGuestWithUser(authenticatedUser);
    await prefs.remove(_emailForSignInKey);

    return authenticatedUser;
  }

  Future<User> loginWithGoogle() async {
    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    final credential = firebase_auth.GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(credential);

    final user = User.fromFirebaseUser(userCredential.user);
    final idToken = await userCredential.user?.getIdToken();
    if (idToken == null) {
      throw Exception('Failed to get ID token');
    }

    final authenticatedUser = await _api.authenticate(AuthRequest(token: idToken, user: user));

    await _replaceGuestWithUser(authenticatedUser);
    return authenticatedUser;
  }

  Future<User> logout(User currentUser) async {
    await _api.logout(currentUser);
    return await clearSession(currentUser);
  }

  Future<User> clearSession(User currentUser) async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
    await _api.clearToken();

    await _deleteUser(currentUser.id);

    final newGuest = User.guest();
    await _saveUser(newGuest);

    return newGuest;
  }
}
