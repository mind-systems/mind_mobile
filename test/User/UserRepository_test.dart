import 'package:flutter_test/flutter_test.dart';
import 'package:mind/User/IAuthApi.dart';
import 'package:mind/User/IUserApi.dart';
import 'package:mind/Core/Api/Models/GoogleAuthRequest.dart';
import 'package:mind/Core/Api/Models/SendCodeRequest.dart';
import 'package:mind/Core/Api/Models/UpdateUserRequest.dart';
import 'package:mind/Core/Api/Models/VerifyCodeRequest.dart';
import 'package:mind/Core/Database/IUserDao.dart';
import 'package:mind/User/Infrastructure/IGoogleAuthProvider.dart';
import 'package:mind/User/Infrastructure/ISecureStorage.dart';
import 'package:mind/User/Models/GoogleSignInCanceledException.dart';
import 'package:mind/User/Models/User.dart';
import 'package:mind/User/UserRepository.dart';

class FakeUserApi implements IUserApi {
  @override
  Future<void> updateUser(UpdateUserRequest request) async {}
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeUserDao implements IUserDao {
  User? _stored;

  @override
  Future<User?> getUser() async => _stored;

  @override
  Future<void> saveUser(User user) async => _stored = user;

  @override
  Future<void> deleteUser(String id) async {
    if (_stored?.id == id) _stored = null;
  }
}

class FakeAuthApi implements IAuthApi {
  String? lastSentEmail;
  String? lastVerifiedEmail;
  String? lastVerifiedCode;
  String? lastGoogleServerAuthCode;
  User? loggedOutUser;
  bool tokenCleared = false;

  User verifyCodeResponse = _authenticatedUser;
  User googleAuthResponse = _authenticatedUser;

  @override
  Future<void> sendCode(SendCodeRequest request) async {
    lastSentEmail = request.email;
  }

  @override
  Future<User> verifyCode(VerifyCodeRequest request) async {
    lastVerifiedEmail = request.email;
    lastVerifiedCode = request.code;
    return verifyCodeResponse;
  }

  @override
  Future<User> googleAuth(GoogleAuthRequest request) async {
    lastGoogleServerAuthCode = request.serverAuthCode;
    return googleAuthResponse;
  }

  @override
  Future<void> logout(User user) async {
    loggedOutUser = user;
  }

  @override
  Future<void> clearToken() async {
    tokenCleared = true;
  }
}

class FakeGoogleAuthProvider implements IGoogleAuthProvider {
  String serverAuthCodeToReturn = 'fake-server-auth-code';
  bool cancelOnGetCode = false;
  bool signedOut = false;

  @override
  Future<String> getServerAuthCode() async {
    if (cancelOnGetCode) throw GoogleSignInCanceledException();
    return serverAuthCodeToReturn;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

class FakeSecureStorage implements ISecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _authenticatedUser = User(
  id: 'user-123',
  email: 'test@example.com',
  name: 'Test User',
  language: '',
  isGuest: false,
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserRepository _makeRepo({
  FakeUserDao? dao,
  FakeAuthApi? api,
  FakeUserApi? userApi,
  FakeGoogleAuthProvider? google,
  FakeSecureStorage? storage,
}) {
  return UserRepository(
    userDao: dao ?? FakeUserDao(),
    api: api ?? FakeAuthApi(),
    userApi: userApi ?? FakeUserApi(),
    google: google ?? FakeGoogleAuthProvider(),
    storage: storage ?? FakeSecureStorage(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('loadUser', () {
    test('returns existing user from DB', () async {
      final dao = FakeUserDao();
      await dao.saveUser(_authenticatedUser);
      final repo = _makeRepo(dao: dao);

      final user = await repo.loadUser();

      expect(user.id, _authenticatedUser.id);
      expect(user.isGuest, false);
    });

    test('creates and saves a guest when DB is empty', () async {
      final dao = FakeUserDao();
      final repo = _makeRepo(dao: dao);

      final user = await repo.loadUser();

      expect(user.isGuest, true);
      expect(await dao.getUser(), isNotNull);
    });
  });

  group('sendPasswordlessSignInLink', () {
    test('calls api.sendCode with email', () async {
      final api = FakeAuthApi();
      final storage = FakeSecureStorage();
      final repo = _makeRepo(api: api, storage: storage);

      await repo.sendPasswordlessSignInLink('user@example.com');

      expect(api.lastSentEmail, 'user@example.com');
    });

    test('writes email to storage', () async {
      final storage = FakeSecureStorage();
      final repo = _makeRepo(storage: storage);

      await repo.sendPasswordlessSignInLink('user@example.com');

      expect(await storage.read('pendingSignInEmail'), 'user@example.com');
    });
  });

  group('completePasswordlessSignIn', () {
    test('reads email from storage and calls api.verifyCode', () async {
      final api = FakeAuthApi();
      final storage = FakeSecureStorage();
      await storage.write('pendingSignInEmail', 'user@example.com');
      final repo = _makeRepo(api: api, storage: storage);

      await repo.completePasswordlessSignIn('123456');

      expect(api.lastVerifiedEmail, 'user@example.com');
      expect(api.lastVerifiedCode, '123456');
    });

    test('replaces guest in DB with authenticated user', () async {
      final dao = FakeUserDao();
      final guest = User.guest();
      await dao.saveUser(guest);
      final storage = FakeSecureStorage();
      await storage.write('pendingSignInEmail', 'user@example.com');
      final repo = _makeRepo(dao: dao, storage: storage);

      final result = await repo.completePasswordlessSignIn('123456');

      expect(result.isGuest, false);
      final stored = await dao.getUser();
      expect(stored?.id, _authenticatedUser.id);
    });

    test('deletes pending email from storage after success', () async {
      final storage = FakeSecureStorage();
      await storage.write('pendingSignInEmail', 'user@example.com');
      final repo = _makeRepo(storage: storage);

      await repo.completePasswordlessSignIn('123456');

      expect(await storage.read('pendingSignInEmail'), isNull);
    });

    test('throws when no pending email in storage', () async {
      final repo = _makeRepo();

      expect(
        repo.completePasswordlessSignIn('123456'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('authenticateWithGoogle', () {
    test('passes serverAuthCode to api.googleAuth', () async {
      final api = FakeAuthApi();
      final repo = _makeRepo(api: api);

      await repo.authenticateWithGoogle(serverAuthCode: 'my-auth-code');

      expect(api.lastGoogleServerAuthCode, 'my-auth-code');
    });

    test('replaces guest in DB with authenticated user', () async {
      final dao = FakeUserDao();
      final guest = User.guest();
      await dao.saveUser(guest);
      final repo = _makeRepo(dao: dao);

      final result = await repo.authenticateWithGoogle(serverAuthCode: 'code');

      expect(result.isGuest, false);
      final stored = await dao.getUser();
      expect(stored?.id, _authenticatedUser.id);
    });
  });

  group('getGoogleServerAuthCode', () {
    test('returns server auth code from google provider', () async {
      final google = FakeGoogleAuthProvider();
      google.serverAuthCodeToReturn = 'my-auth-code';
      final repo = _makeRepo(google: google);

      final code = await repo.getGoogleServerAuthCode();

      expect(code, 'my-auth-code');
    });

    test('propagates GoogleSignInCanceledException', () async {
      final google = FakeGoogleAuthProvider();
      google.cancelOnGetCode = true;
      final repo = _makeRepo(google: google);

      expect(
        repo.getGoogleServerAuthCode(),
        throwsA(isA<GoogleSignInCanceledException>()),
      );
    });
  });

  group('logout', () {
    test('calls api.logout then clears session', () async {
      final api = FakeAuthApi();
      final google = FakeGoogleAuthProvider();
      final dao = FakeUserDao();
      await dao.saveUser(_authenticatedUser);
      final repo = _makeRepo(dao: dao, api: api, google: google);

      final newGuest = await repo.logout(_authenticatedUser);

      expect(api.loggedOutUser?.id, _authenticatedUser.id);
      expect(api.tokenCleared, true);
      expect(google.signedOut, true);
      expect(newGuest.isGuest, true);
    });
  });

  group('clearSession', () {
    test('signs out google, clears token, deletes user, saves new guest', () async {
      final api = FakeAuthApi();
      final google = FakeGoogleAuthProvider();
      final dao = FakeUserDao();
      await dao.saveUser(_authenticatedUser);
      final repo = _makeRepo(dao: dao, api: api, google: google);

      final newGuest = await repo.clearSession(_authenticatedUser);

      expect(google.signedOut, true);
      expect(api.tokenCleared, true);
      expect(newGuest.isGuest, true);
      final stored = await dao.getUser();
      expect(stored?.isGuest, true);
    });
  });
}
