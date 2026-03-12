import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind/User/LogoutNotifier.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Models/User.dart';
import 'package:mind/User/UserNotifier.dart';
import 'package:mind/User/UserRepository.dart';

// ---------------------------------------------------------------------------
// Fake UserRepository
// ---------------------------------------------------------------------------

class FakeUserRepository implements UserRepository {
  Completer<User>? _completeSignInCompleter;
  String? lastSentEmail;
  String? lastVerifiedCode;
  String? lastVerifiedLanguage;
  String? lastGoogleLanguage;
  String? lastUpdatedLanguage;
  String? lastUpdatedName;

  @override
  Future<void> sendPasswordlessSignInLink(String email, {String language = 'en'}) async {
    lastSentEmail = email;
  }

  @override
  Future<User> completePasswordlessSignIn(String code, {String? language}) {
    lastVerifiedCode = code;
    lastVerifiedLanguage = language;
    _completeSignInCompleter = Completer<User>();
    return _completeSignInCompleter!.future;
  }

  void succeedSignIn(User user) => _completeSignInCompleter?.complete(user);
  void failSignIn(Object error) =>
      _completeSignInCompleter?.completeError(error);

  @override
  Future<User> loadUser() async => _guestUser;

  @override
  Future<void> pickGoogleAccount() async {}

  @override
  Future<User> authenticateWithGoogle({String? language}) async {
    lastGoogleLanguage = language;
    return _guestUser;
  }

  @override
  Future<void> updateLanguage(String language) async {
    lastUpdatedLanguage = language;
  }

  @override
  Future<void> updateName(String name) async {
    lastUpdatedName = name;
  }

  @override
  Future<User> logout(User currentUser) async => _guestUser;

  @override
  Future<User> clearSession(User currentUser) async => _guestUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _guestUser = User(
  id: 'guest-id',
  email: '',
  name: 'Guest',
  language: '',
  isGuest: true,
);

final _authenticatedUser = User(
  id: 'user-id',
  email: 'test@example.com',
  name: 'Test User',
  language: 'ru',
  isGuest: false,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeUserRepository fakeRepo;
  late LogoutNotifier logoutNotifier;
  late UserNotifier userNotifier;

  setUp(() {
    fakeRepo = FakeUserRepository();
    logoutNotifier = LogoutNotifier();
    userNotifier = UserNotifier(
      repository: fakeRepo,
      logoutNotifier: logoutNotifier,
      initialUser: _guestUser,
    );
  });

  tearDown(() {
    userNotifier.dispose();
    logoutNotifier.dispose();
  });

  group('sendPasswordlessSignInLink', () {
    test('delegates email to repository', () async {
      await userNotifier.sendPasswordlessSignInLink('user@example.com');
      expect(fakeRepo.lastSentEmail, 'user@example.com');
    });
  });

  group('completePasswordlessSignIn', () {
    test('passes code to repository', () async {
      final future = userNotifier.completePasswordlessSignIn('123456');
      fakeRepo.succeedSignIn(_authenticatedUser);
      await future;

      expect(fakeRepo.lastVerifiedCode, '123456');
    });

    test('passes language to repository', () async {
      final future = userNotifier.completePasswordlessSignIn('123456', language: 'en');
      fakeRepo.succeedSignIn(_authenticatedUser);
      await future;

      expect(fakeRepo.lastVerifiedLanguage, 'en');
    });

    test('language defaults to null when not provided', () async {
      final future = userNotifier.completePasswordlessSignIn('123456');
      fakeRepo.succeedSignIn(_authenticatedUser);
      await future;

      expect(fakeRepo.lastVerifiedLanguage, isNull);
    });

    test('emits AuthenticatedState on success', () async {
      final future = userNotifier.completePasswordlessSignIn('123456');
      fakeRepo.succeedSignIn(_authenticatedUser);
      await future;

      expect(userNotifier.currentState, isA<AuthenticatedState>());
      expect(userNotifier.currentState.user.email, 'test@example.com');
    });

    test('sets authInProgress=true while in flight, then false', () async {
      final values = <bool>[];
      userNotifier.authInProgressStream.skip(1).listen(values.add);

      final future = userNotifier.completePasswordlessSignIn('123456');
      fakeRepo.succeedSignIn(_authenticatedUser);
      await future;
      await Future.delayed(Duration.zero);

      expect(values, [true, false]);
    });

    test('sets authInProgress=false after failure', () async {
      final values = <bool>[];
      userNotifier.authInProgressStream.skip(1).listen(values.add);

      final future = userNotifier.completePasswordlessSignIn('bad-code');
      fakeRepo.failSignIn(Exception('invalid code'));
      await expectLater(future, throwsA(isA<Exception>()));
      await Future.delayed(Duration.zero);

      expect(values, [true, false]);
    });

    test('state remains GuestState after failure', () async {
      final future = userNotifier.completePasswordlessSignIn('bad-code');
      fakeRepo.failSignIn(Exception('invalid code'));
      await expectLater(future, throwsA(isA<Exception>()));

      expect(userNotifier.currentState, isA<GuestState>());
    });
  });

  group('authErrorStream', () {
    test('emits error string when completePasswordlessSignIn fails', () async {
      final errorFuture = expectLater(
        userNotifier.authErrorStream,
        emits(contains('invalid code')),
      );

      final future = userNotifier.completePasswordlessSignIn('bad-code');
      fakeRepo.failSignIn(Exception('invalid code'));

      await expectLater(future, throwsA(isA<Exception>()));
      await errorFuture;
    });

    test('does NOT emit when completePasswordlessSignIn succeeds', () async {
      final errors = <String>[];
      userNotifier.authErrorStream.listen(errors.add);

      final future = userNotifier.completePasswordlessSignIn('123456');
      fakeRepo.succeedSignIn(_authenticatedUser);
      await future;

      await Future.delayed(Duration.zero);
      expect(errors, isEmpty);
    });

    test('does not replay old errors (PublishSubject behavior)', () async {
      final future = userNotifier.completePasswordlessSignIn('bad-code');
      fakeRepo.failSignIn(Exception('old error'));
      await expectLater(future, throwsA(isA<Exception>()));

      final errors = <String>[];
      userNotifier.authErrorStream.listen(errors.add);
      await Future.delayed(Duration.zero);

      expect(errors, isEmpty,
          reason: 'PublishSubject should not replay past events');
    });
  });

  group('updateLanguage', () {
    test('does nothing when guest', () async {
      await userNotifier.updateLanguage('ru');
      expect(fakeRepo.lastUpdatedLanguage, isNull);
    });

    test('delegates to repository when authenticated', () async {
      final future = userNotifier.completePasswordlessSignIn('123456');
      fakeRepo.succeedSignIn(_authenticatedUser);
      await future;

      await userNotifier.updateLanguage('ru');
      expect(fakeRepo.lastUpdatedLanguage, 'ru');
    });
  });

  group('updateName', () {
    test('does nothing when guest', () async {
      await userNotifier.updateName('New Name');
      expect(fakeRepo.lastUpdatedName, isNull);
    });

    test('delegates to repository when authenticated', () async {
      final future = userNotifier.completePasswordlessSignIn('123456');
      fakeRepo.succeedSignIn(_authenticatedUser);
      await future;

      await userNotifier.updateName('New Name');
      expect(fakeRepo.lastUpdatedName, 'New Name');
    });

    test('emits new AuthenticatedState with updated name', () async {
      final future = userNotifier.completePasswordlessSignIn('123456');
      fakeRepo.succeedSignIn(_authenticatedUser);
      await future;

      await userNotifier.updateName('New Name');

      expect(userNotifier.currentState, isA<AuthenticatedState>());
      expect(userNotifier.currentState.user.name, 'New Name');
    });

    test('preserves other user fields when updating name', () async {
      final future = userNotifier.completePasswordlessSignIn('123456');
      fakeRepo.succeedSignIn(_authenticatedUser);
      await future;

      await userNotifier.updateName('New Name');

      final user = userNotifier.currentState.user;
      expect(user.email, _authenticatedUser.email);
      expect(user.language, _authenticatedUser.language);
      expect(user.id, _authenticatedUser.id);
    });
  });
}
