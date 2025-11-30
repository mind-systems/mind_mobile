import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'Models/AuthState.dart';
import 'Models/User.dart';
import 'UserRepository.dart';

class UserNotifier extends Notifier<AuthState> {
  final UserRepository repository;
  final User initialUser;

  UserNotifier({required this.repository, required this.initialUser});

  @override
  AuthState build() {
    return initialUser.isGuest ? GuestState(initialUser) : AuthenticatedState(initialUser);
  }

  Future<void> sendPasswordlessSignInLink(String email) async {
    await repository.sendPasswordlessSignInLink(email);
  }

  Future<void> completePasswordlessSignIn(String emailLink) async {
    final authenticatedUser = await repository.completePasswordlessSignIn(emailLink,);
    state = AuthenticatedState(authenticatedUser);
  }

  Future<void> loginWithGoogle() async {
    final authenticatedUser = await repository.loginWithGoogle();
    state = AuthenticatedState(authenticatedUser);
  }

  Future<void> logout() async {
    final currentUser = state.user;

    final newGuest = await repository.logout(currentUser);
    state = GuestState(newGuest);
  }
}

final userNotifierProvider = NotifierProvider<UserNotifier, AuthState>(() {
  throw UnimplementedError('UserNotifier должен быть передан в ProviderScope');
});
