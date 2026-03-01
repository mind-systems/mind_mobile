import 'dart:async';
import 'dart:developer' as developer;

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
  final BehaviorSubject<bool> _authInProgressSubject = BehaviorSubject<bool>.seeded(false);
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

  Stream<bool> get authInProgressStream => _authInProgressSubject.stream;

  AuthState get currentState => _subject.value;

  User get currentUser => _subject.value.user;

  Future<void> sendPasswordlessSignInLink(String email) async {
    developer.log('[Auth] UserNotifier.sendPasswordlessSignInLink: email=$email', name: 'UserNotifier');
    try {
      await repository.sendPasswordlessSignInLink(email);
      developer.log('[Auth] UserNotifier.sendPasswordlessSignInLink: success', name: 'UserNotifier');
    } catch (e, st) {
      developer.log('[Auth] UserNotifier.sendPasswordlessSignInLink: error=$e', name: 'UserNotifier', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> completePasswordlessSignIn(String emailLink) async {
    developer.log('[Auth] UserNotifier.completePasswordlessSignIn: start', name: 'UserNotifier');
    _authInProgressSubject.add(true);
    developer.log('[Auth] UserNotifier: authInProgress → true (emailLink)', name: 'UserNotifier');
    try {
      final authenticatedUser = await repository.completePasswordlessSignIn(emailLink);
      developer.log('[Auth] UserNotifier.completePasswordlessSignIn: success, userId=${authenticatedUser.id}', name: 'UserNotifier');
      _subject.add(AuthenticatedState(authenticatedUser));
    } catch (e, st) {
      developer.log('[Auth] UserNotifier.completePasswordlessSignIn: error=$e', name: 'UserNotifier', error: e, stackTrace: st);
      rethrow;
    } finally {
      _authInProgressSubject.add(false);
      developer.log('[Auth] UserNotifier: authInProgress → false (emailLink)', name: 'UserNotifier');
    }
  }

  Future<void> loginWithGoogle() async {
    developer.log('[Auth] UserNotifier.loginWithGoogle: start', name: 'UserNotifier');
    _authInProgressSubject.add(true);
    developer.log('[Auth] UserNotifier: authInProgress → true (google)', name: 'UserNotifier');
    try {
      final authenticatedUser = await repository.loginWithGoogle();
      developer.log('[Auth] UserNotifier.loginWithGoogle: success, userId=${authenticatedUser.id}', name: 'UserNotifier');
      _subject.add(AuthenticatedState(authenticatedUser));
    } catch (e, st) {
      developer.log('[Auth] UserNotifier.loginWithGoogle: error=$e', name: 'UserNotifier', error: e, stackTrace: st);
      rethrow;
    } finally {
      _authInProgressSubject.add(false);
      developer.log('[Auth] UserNotifier: authInProgress → false (google)', name: 'UserNotifier');
    }
  }

  Future<void> logout() async {
    final currentUser = _subject.value.user;
    final newGuest = await repository.logout(currentUser);
    _subject.add(GuestState(newGuest));
  }

  Future<void> clearSession() async {
    // защита от циклических попыток вылогинить юзера, если сервер продолжает на все запросы отдавать 401
    // логика логина в определенные модули не зависит от 401 ошибки, а должна решаться на месте
    if (_subject.value is GuestState) return;

    final currentUser = _subject.value.user;
    final newGuest = await repository.clearSession(currentUser);
    _subject.add(GuestState(newGuest));
  }

  void dispose() {
    _logoutSubscription?.cancel();
    _authInProgressSubject.close();
    _subject.close();
  }
}
