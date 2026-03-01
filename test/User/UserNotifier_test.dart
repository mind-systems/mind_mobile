import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind/User/LogoutNotifier.dart';
import 'package:mind/User/Models/User.dart';
import 'package:mind/User/UserNotifier.dart';
import 'package:mind/User/UserRepository.dart';

// ---------------------------------------------------------------------------
// Fake UserRepository — overrides only the methods UserNotifier calls
// ---------------------------------------------------------------------------

class FakeUserRepository implements UserRepository {
  Completer<User>? _completeSignInCompleter;

  @override
  Future<User> completePasswordlessSignIn(String emailLink) {
    _completeSignInCompleter = Completer<User>();
    return _completeSignInCompleter!.future;
  }

  void succeedSignIn(User user) => _completeSignInCompleter?.complete(user);
  void failSignIn(Object error) =>
      _completeSignInCompleter?.completeError(error);

  // -- Stubs for other methods (not exercised in these tests) --

  @override
  Future<User> loadUser() async => _guestUser;

  @override
  Future<void> sendPasswordlessSignInLink(String email) async {}

  @override
  Future<User> loginWithGoogle() async => _authenticatedUser;

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
  isGuest: true,
);

final _authenticatedUser = User(
  id: 'user-id',
  firebaseUid: 'firebase-uid',
  email: 'test@example.com',
  name: 'Test User',
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

  group('authErrorStream', () {
    test('emits error string when completePasswordlessSignIn fails', () async {
      // Set up expectation on the stream BEFORE triggering the error
      final errorFuture = expectLater(
        userNotifier.authErrorStream,
        emits(contains('invalid link')),
      );

      final future = userNotifier.completePasswordlessSignIn('https://example.com/link');
      fakeRepo.failSignIn(Exception('invalid link'));

      // completePasswordlessSignIn rethrows, so we expect it to throw
      await expectLater(future, throwsA(isA<Exception>()));
      await errorFuture;
    });

    test('does NOT emit when completePasswordlessSignIn succeeds', () async {
      final errors = <String>[];
      userNotifier.authErrorStream.listen(errors.add);

      final future = userNotifier.completePasswordlessSignIn('https://example.com/link');
      fakeRepo.succeedSignIn(_authenticatedUser);
      await future;

      // Allow microtasks to settle
      await Future.delayed(Duration.zero);

      expect(errors, isEmpty);
    });

    test('does not replay old errors (PublishSubject behavior)', () async {
      // Trigger an error before subscribing
      final future = userNotifier.completePasswordlessSignIn('https://example.com/link');
      fakeRepo.failSignIn(Exception('old error'));
      await expectLater(future, throwsA(isA<Exception>()));

      // Now subscribe — should NOT receive the old error
      final errors = <String>[];
      userNotifier.authErrorStream.listen(errors.add);

      // Allow microtasks to settle
      await Future.delayed(Duration.zero);

      expect(errors, isEmpty,
          reason: 'PublishSubject should not replay past events');
    });
  });
}
