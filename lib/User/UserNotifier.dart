import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'package:mind/User/LogoutNotifier.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Models/User.dart';
import 'package:mind/User/UserRepository.dart';

/// Доменный нотифаер — источник правды по состоянию аутентификации.
class UserNotifier {
  final UserRepository repository;
  final LogoutNotifier logoutNotifier;

  final BehaviorSubject<AuthState> _subject;
  StreamSubscription<void>? _logoutSubscription;

  UserNotifier({
    required this.repository,
    required this.logoutNotifier,
    required User initialUser,
  }) : _subject = BehaviorSubject<AuthState>.seeded(
    initialUser.isGuest ? GuestState(initialUser) : AuthenticatedState(initialUser),
  ) {
    _logoutSubscription = logoutNotifier.stream.listen((_) {
      clearSession();
    });
  }

  Stream<AuthState> get stream => _subject.stream;

  AuthState get currentState => _subject.value;

  User get currentUser => _subject.value.user;

  Future<void> sendPasswordlessSignInLink(String email) async {
    await repository.sendPasswordlessSignInLink(email);
  }

  Future<void> completePasswordlessSignIn(String emailLink) async {
    final authenticatedUser = await repository.completePasswordlessSignIn(emailLink);
    _subject.add(AuthenticatedState(authenticatedUser));
  }

  Future<void> loginWithGoogle() async {
    final authenticatedUser = await repository.loginWithGoogle();
    _subject.add(AuthenticatedState(authenticatedUser));
  }

  Future<void> logout() async {
    final currentUser = _subject.value.user;
    final newGuest = await repository.logout(currentUser);
    _subject.add(GuestState(newGuest));
  }

  Future<void> clearSession() async {
    final currentUser = _subject.value.user;
    final newGuest = await repository.clearSession(currentUser);
    _subject.add(GuestState(newGuest));
  }

  void dispose() {
    _logoutSubscription?.cancel();
    _subject.close();
  }
}
