import 'dart:async';
import 'dart:developer';

import 'package:rxdart/rxdart.dart';

import 'package:mind/User/LogoutNotifier.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Models/GoogleSignInCanceledException.dart';
import 'package:mind/User/Models/User.dart';
import 'package:mind/User/UserRepository.dart';

/// Доменный нотифаер — источник правды по состоянию аутентификации.
class UserNotifier {
  final UserRepository repository;
  final LogoutNotifier logoutNotifier;

  final BehaviorSubject<AuthState> _subject;
  final BehaviorSubject<bool> _authInProgressSubject = BehaviorSubject<bool>.seeded(false);
  final PublishSubject<String> _authErrorSubject = PublishSubject<String>();
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

  Stream<String> get authErrorStream => _authErrorSubject.stream;

  AuthState get currentState => _subject.value;

  User get currentUser => _subject.value.user;

  Future<void> sendPasswordlessSignInLink(String email) async {
    await repository.sendPasswordlessSignInLink(email);
  }

  Future<void> completePasswordlessSignIn(String code, {String? language}) async {
    _authInProgressSubject.add(true);
    try {
      final authenticatedUser = await repository.completePasswordlessSignIn(code, language: language);
      _subject.add(AuthenticatedState(authenticatedUser));
    } catch (e) {
      _authErrorSubject.add(e.toString());
      rethrow;
    } finally {
      _authInProgressSubject.add(false);
    }
  }

  Future<void> loginWithGoogle({String? language}) async {
    // Phase 1: show Google account picker — do not block UI yet
    try {
      await repository.pickGoogleAccount();
    } on GoogleSignInCanceledException {
      // User cancelled — nothing to do, don't touch the UI
      return;
    }

    // Phase 2: user picked an account — now block UI for server auth
    _authInProgressSubject.add(true);
    try {
      final authenticatedUser = await repository.authenticateWithGoogle(language: language);
      _subject.add(AuthenticatedState(authenticatedUser));
    } catch (e) {
      log('[UserNotifier] loginWithGoogle error: $e');
      _authErrorSubject.add('Не удалось войти через Google');
    } finally {
      _authInProgressSubject.add(false);
    }
  }

  Future<void> updateLanguage(String language) async {
    if (_subject.value is! AuthenticatedState) return;
    await repository.updateLanguage(language);
  }

  Future<void> updateName(String name) async {
    if (_subject.value is! AuthenticatedState) return;
    await repository.updateName(name);
    final updated = _subject.value.user.copyWith(name: name);
    _subject.add(AuthenticatedState(updated));
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
    _authErrorSubject.close();
    _authInProgressSubject.close();
    _subject.close();
  }
}
