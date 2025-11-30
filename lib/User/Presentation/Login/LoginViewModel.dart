import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'LoginState.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/UserProvider.dart';

// Базовый провайдер для LoginViewModel (переопределяется в модуле)
final loginViewModelProvider = StateNotifierProvider<LoginViewModel, LoginState>((ref) {
  throw UnimplementedError('LoginViewModel должен быть передан через override в LoginModule');
});

class LoginViewModel extends StateNotifier<LoginState> {
  final Ref ref;

  void Function(String error)? onErrorEvent;
  void Function()? onSuccessEvent;
  void Function()? onAuthenticatedEvent;

  LoginViewModel({required this.ref, required String returnPath})
    : super(LoginState(returnPath: returnPath)) {
    ref.listen<AuthState>(userNotifierProvider, (previous, next) {
      if (next is AuthenticatedState) {
        onAuthenticatedEvent?.call();
      }
    });
  }

  // Inputs
  void updateEmail(String email) {
    state = state.copyWith(email: email);
  }

  Future<void> sendPasswordlessSignInLink() async {
    state = state.copyWith(isLoading: true);

    try {
      await ref
          .read(userNotifierProvider.notifier)
          .sendPasswordlessSignInLink(state.email);

      state = state.copyWith(isLoading: false);
      onSuccessEvent?.call();
    } catch (e) {
      state = state.copyWith(isLoading: false);
      onErrorEvent?.call('Ошибка отправки ссылки: ${e.toString()}');
    }
  }

  Future<void> loginWithGoogle() async {
    state = state.copyWith(isLoading: true);

    try {
      await ref.read(userNotifierProvider.notifier).loginWithGoogle();

      state = state.copyWith(isLoading: false);
      onSuccessEvent?.call();
    } catch (e) {
      state = state.copyWith(isLoading: false);
      onErrorEvent?.call('Ошибка входа через Google: ${e.toString()}');
    }
  }
}
