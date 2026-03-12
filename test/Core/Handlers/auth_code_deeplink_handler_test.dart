import 'package:flutter_test/flutter_test.dart';
import 'package:mind/Core/Environment.dart';
import 'package:mind/Core/Handlers/AuthCodeDeeplinkHandler.dart';
import 'package:mind/User/LogoutNotifier.dart';
import 'package:mind/User/Models/User.dart';
import 'package:mind/User/UserNotifier.dart';
import 'package:mind/User/UserRepository.dart';

// ---------------------------------------------------------------------------
// Fake UserRepository
// ---------------------------------------------------------------------------

class FakeUserRepository implements UserRepository {
  String? lastVerifiedCode;

  @override
  Future<User> completePasswordlessSignIn(String code, {String? language}) async {
    lastVerifiedCode = code;
    return User(
      id: 'user-id',
      email: 'test@example.com',
      name: 'Test User',
      language: '',
      isGuest: false,
    );
  }

  @override
  Future<void> sendPasswordlessSignInLink(String email, {String language = 'en'}) async {}

  @override
  Future<User> loadUser() async => User(
        id: 'guest-id',
        email: '',
        name: 'Guest',
        language: '',
        isGuest: true,
      );

  @override
  Future<User> logout(User currentUser) async => currentUser;

  @override
  Future<User> clearSession(User currentUser) async => currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    Environment.initDev();
  });

  late FakeUserRepository fakeRepo;
  late LogoutNotifier logoutNotifier;
  late UserNotifier userNotifier;
  late AuthCodeDeeplinkHandler handler;

  setUp(() {
    fakeRepo = FakeUserRepository();
    logoutNotifier = LogoutNotifier();
    userNotifier = UserNotifier(
      repository: fakeRepo,
      logoutNotifier: logoutNotifier,
      initialUser: User(
        id: 'guest-id',
        email: '',
        name: 'Guest',
        language: '',
        isGuest: true,
      ),
    );
    handler = AuthCodeDeeplinkHandler(userNotifier: userNotifier);
  });

  tearDown(() {
    userNotifier.dispose();
    logoutNotifier.dispose();
  });

  group('handle', () {
    test('returns false for unrecognised host', () async {
      final uri = Uri.parse('https://evil.com/deeplink-auth?code=123456');
      final result = await handler.handle(uri);
      expect(result, isFalse);
      expect(fakeRepo.lastVerifiedCode, isNull);
    });

    test('returns false for wrong path', () async {
      final uri = Uri.parse('https://dev.mind-awake.life/some-other-path?code=123456');
      final result = await handler.handle(uri);
      expect(result, isFalse);
      expect(fakeRepo.lastVerifiedCode, isNull);
    });

    test('returns false when code param is missing', () async {
      final uri = Uri.parse('https://dev.mind-awake.life/deeplink-auth');
      final result = await handler.handle(uri);
      expect(result, isFalse);
      expect(fakeRepo.lastVerifiedCode, isNull);
    });

    test('returns false when code param is empty', () async {
      final uri = Uri.parse('https://dev.mind-awake.life/deeplink-auth?code=');
      final result = await handler.handle(uri);
      expect(result, isFalse);
      expect(fakeRepo.lastVerifiedCode, isNull);
    });

    test('returns true and passes code to UserNotifier on valid URI', () async {
      final uri = Uri.parse('https://dev.mind-awake.life/deeplink-auth?code=123456');
      final result = await handler.handle(uri);
      expect(result, isTrue);
      expect(fakeRepo.lastVerifiedCode, '123456');
    });
  });
}
