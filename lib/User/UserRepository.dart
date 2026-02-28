import 'dart:developer' as developer;

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
    developer.log('[Auth] sendPasswordlessSignInLink: email=$email', name: 'UserRepository');
    final prefs = await SharedPreferences.getInstance();

    final actionCodeSettings = firebase_auth.ActionCodeSettings(
      linkDomain: Environment.instance.linkDomain,
      url: Environment.instance.deeplinkUrl,
      handleCodeInApp: true,
      iOSBundleId: Environment.instance.iosBundleId,
      androidPackageName: Environment.instance.androidPackageName,
      androidInstallApp: true,
    );
    developer.log('[Auth] ActionCodeSettings: linkDomain=${Environment.instance.linkDomain}, url=${Environment.instance.deeplinkUrl}, iosBundleId=${Environment.instance.iosBundleId}', name: 'UserRepository');

    try {
      await _firebaseAuth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );
      developer.log('[Auth] sendSignInLinkToEmail: success', name: 'UserRepository');
    } on firebase_auth.FirebaseAuthException catch (e) {
      developer.log('[Auth] Firebase sendSignInLinkToEmail error: code=${e.code}, message=${e.message}', name: 'UserRepository', error: e);
      rethrow;
    }

    await prefs.setString(_emailForSignInKey, email);
    await prefs.reload();
  }

  Future<User> completePasswordlessSignIn(String emailLink) async {
    developer.log('[Auth] completePasswordlessSignIn: link=$emailLink', name: 'UserRepository');
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_emailForSignInKey);
    developer.log('[Auth] stored email for sign-in: $email', name: 'UserRepository');

    if (email == null) {
      throw Exception('Email not found. Please try signing in again.');
    }

    final firebase_auth.UserCredential userCredential;
    try {
      userCredential = await _firebaseAuth.signInWithEmailLink(
        email: email,
        emailLink: emailLink,
      );
      developer.log('[Auth] signInWithEmailLink: success, uid=${userCredential.user?.uid}', name: 'UserRepository');
    } on firebase_auth.FirebaseAuthException catch (e) {
      developer.log('[Auth] Firebase signInWithEmailLink error: code=${e.code}, message=${e.message}', name: 'UserRepository', error: e);
      rethrow;
    }

    final String? idToken = await userCredential.user?.getIdToken();
    if (idToken == null) {
      developer.log('[Auth] completePasswordlessSignIn: idToken is null', name: 'UserRepository');
      throw Exception('Failed to get ID token');
    }
    developer.log('[Auth] idToken obtained (length=${idToken.length})', name: 'UserRepository');

    final firebaseUser = userCredential.user;
    if (firebaseUser == null) {
      developer.log('[Auth] completePasswordlessSignIn: firebaseUser is null', name: 'UserRepository');
      throw Exception('Failed to get Firebase user');
    }

    final user = User.fromFirebaseUser(firebaseUser);
    final authRequest = AuthRequest(token: idToken, user: user);
    developer.log('[Auth] calling api.authenticate: uid=${user.id}, email=${user.email}', name: 'UserRepository');
    final authenticatedUser = await _api.authenticate(authRequest);
    developer.log('[Auth] api.authenticate: success, userId=${authenticatedUser.id}', name: 'UserRepository');

    await _replaceGuestWithUser(authenticatedUser);
    await prefs.remove(_emailForSignInKey);

    return authenticatedUser;
  }

  Future<User> loginWithGoogle() async {
    developer.log('[Auth] loginWithGoogle: calling _googleSignIn.authenticate()', name: 'UserRepository');
    final GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
      developer.log('[Auth] Google authenticate: success, email=${googleUser.email}, id=${googleUser.id}', name: 'UserRepository');
    } catch (e) {
      developer.log('[Auth] Google authenticate error: $e', name: 'UserRepository', error: e);
      rethrow;
    }

    final GoogleSignInAuthentication googleAuth;
    try {
      googleAuth = googleUser.authentication;
      developer.log('[Auth] Google auth tokens: idToken=${googleAuth.idToken != null ? "present (len=${googleAuth.idToken!.length})" : "NULL"}', name: 'UserRepository');
    } catch (e) {
      developer.log('[Auth] Google authentication tokens error: $e', name: 'UserRepository', error: e);
      rethrow;
    }

    if (googleAuth.idToken == null) {
      developer.log('[Auth] loginWithGoogle: idToken from Google is NULL — cannot proceed', name: 'UserRepository');
      throw Exception('Google Sign-In did not return an idToken');
    }

    final credential = firebase_auth.GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    developer.log('[Auth] Firebase credential created, calling signInWithCredential', name: 'UserRepository');

    final firebase_auth.UserCredential userCredential;
    try {
      userCredential = await _firebaseAuth.signInWithCredential(credential);
      developer.log('[Auth] Firebase signInWithCredential: success, uid=${userCredential.user?.uid}, email=${userCredential.user?.email}', name: 'UserRepository');
    } on firebase_auth.FirebaseAuthException catch (e) {
      developer.log('[Auth] Firebase signInWithCredential error: code=${e.code}, message=${e.message}, credential=${e.credential}', name: 'UserRepository', error: e);
      rethrow;
    }

    final user = User.fromFirebaseUser(userCredential.user);
    final idToken = await userCredential.user?.getIdToken();
    if (idToken == null) {
      developer.log('[Auth] loginWithGoogle: Firebase idToken is null after signIn', name: 'UserRepository');
      throw Exception('Failed to get ID token');
    }
    developer.log('[Auth] Firebase idToken obtained (length=${idToken.length}), calling api.authenticate', name: 'UserRepository');

    final User authenticatedUser;
    try {
      authenticatedUser = await _api.authenticate(AuthRequest(token: idToken, user: user));
      developer.log('[Auth] api.authenticate: success, userId=${authenticatedUser.id}', name: 'UserRepository');
    } catch (e) {
      developer.log('[Auth] api.authenticate error: $e', name: 'UserRepository', error: e);
      rethrow;
    }

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
