import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Models/GoogleSignInCanceledException.dart';
import 'package:mind/User/Presentation/Login/ILoginService.dart';
import 'package:mind/User/Presentation/Login/LoginState.dart';

final loginViewModelProvider = StateNotifierProvider<LoginViewModel, LoginState>((ref) {
  throw UnimplementedError('LoginViewModel должен быть передан через override в LoginModule');
});

class LoginViewModel extends StateNotifier<LoginState> {
  final ILoginService service;

  void Function(String error)? onErrorEvent;
  void Function()? onSuccessEvent;
  void Function()? onAuthenticatedEvent;

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<bool>? _authInProgressSubscription;

  LoginViewModel({required this.service, required String returnPath})
      : super(LoginState(returnPath: returnPath)) {
    _authSubscription = service.observeAuthState().listen((authState) {
      if (authState is AuthenticatedState) {
        onAuthenticatedEvent?.call();
      }
    });

    _authInProgressSubscription = service.observeAuthInProgress().listen((value) {
      developer.log('[Auth] LoginViewModel: isLoginInProgress → $value', name: 'LoginViewModel');
      state = state.copyWith(isLoginInProgress: value);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authInProgressSubscription?.cancel();
    super.dispose();
  }

  void updateEmail(String email) {
    state = state.copyWith(email: email);
  }

  Future<void> sendPasswordlessSignInLink() async {
    developer.log('[Auth] LoginViewModel.sendPasswordlessSignInLink: email=${state.email}', name: 'LoginViewModel');
    state = state.copyWith(isLoading: true);

    try {
      await service.sendPasswordlessSignInLink(state.email);

      developer.log('[Auth] LoginViewModel.sendPasswordlessSignInLink: success', name: 'LoginViewModel');
      state = state.copyWith(isLoading: false);
      onSuccessEvent?.call();
    } catch (e, st) {
      developer.log('[Auth] LoginViewModel.sendPasswordlessSignInLink: error=${e.runtimeType}: $e', name: 'LoginViewModel', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false);
      onErrorEvent?.call('Ошибка отправки ссылки: ${e.toString()}');
    }
  }

  Future<void> loginWithGoogle() async {
    developer.log('[Auth] LoginViewModel.loginWithGoogle: start', name: 'LoginViewModel');

    try {
      await service.loginWithGoogle();

      developer.log('[Auth] LoginViewModel.loginWithGoogle: success', name: 'LoginViewModel');
      onSuccessEvent?.call();
    } on GoogleSignInCanceledException {
      // User cancelled — no action needed, isLoginInProgress handles overlay
    } catch (e, st) {
      developer.log('[Auth] LoginViewModel.loginWithGoogle: error=${e.runtimeType}: $e', name: 'LoginViewModel', error: e, stackTrace: st);
      onErrorEvent?.call('Ошибка входа через Google: ${e.toString()}');
    }
  }
}
