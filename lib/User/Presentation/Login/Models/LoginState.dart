enum LoginError {
  sendCodeFailed,
  codeInvalidOrExpired,
}

class LoginState {
  final String email;
  final bool isLoading;
  final bool isLoginInProgress;

  const LoginState({
    this.email = '',
    this.isLoading = false,
    this.isLoginInProgress = false,
  });

  LoginState copyWith({String? email, bool? isLoading, bool? isLoginInProgress}) {
    return LoginState(
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
      isLoginInProgress: isLoginInProgress ?? this.isLoginInProgress,
    );
  }
}
