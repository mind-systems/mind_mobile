import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Models/GoogleSignInCanceledException.dart';
import 'package:mind/User/Presentation/Login/ILoginService.dart';
import 'package:mind/User/Presentation/Login/Models/LoginState.dart';

final loginViewModelProvider = NotifierProvider<LoginViewModel, LoginState>(() {
  throw UnimplementedError('LoginViewModel must be overridden via ProviderScope');
});

class LoginViewModel extends Notifier<LoginState> {
  final ILoginService service;

  void Function(LoginError error)? onErrorEvent;
  void Function()? onSuccessEvent;
  void Function()? onAuthenticatedEvent;

  LoginViewModel({required this.service});

  @override
  LoginState build() {
    final authSubscription = service.observeAuthState().listen((authState) {
      if (authState is AuthenticatedState) {
        onAuthenticatedEvent?.call();
      }
    });

    final authInProgressSubscription = service.observeAuthInProgress().listen((value) {
      state = state.copyWith(isLoginInProgress: value);
    });

    ref.onDispose(() {
      authSubscription.cancel();
      authInProgressSubscription.cancel();
    });

    return const LoginState();
  }

  void updateEmail(String email) {
    state = state.copyWith(email: email);
  }

  Future<void> sendPasswordlessSignInLink() async {
    state = state.copyWith(isLoading: true);

    try {
      await service.sendPasswordlessSignInLink(state.email);
      state = state.copyWith(isLoading: false);
      onSuccessEvent?.call();
    } catch (e) {
      state = state.copyWith(isLoading: false);
      onErrorEvent?.call(LoginError.sendCodeFailed);
    }
  }

  Future<void> verifyCode(String code) async {
    state = state.copyWith(isLoading: true);

    try {
      await service.completePasswordlessSignIn(code);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      onErrorEvent?.call(LoginError.codeInvalidOrExpired);
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      await service.loginWithGoogle();
      // Navigation happens via onAuthenticatedEvent when UserNotifier emits AuthenticatedState
    } on GoogleSignInCanceledException {
      // Cancellation is handled in UserNotifier; catch here as a safety net
    } catch (_) {
      // Error is already published to authErrorStream by UserNotifier
    }
  }
}
