class LoginState {
  final String email;
  final bool isLoading;
  final bool isLoginInProgress;
  final String returnPath;

  const LoginState({
    this.email = '',
    this.isLoading = false,
    this.isLoginInProgress = false,
    this.returnPath = '/',
  });

  LoginState copyWith({String? email, bool? isLoading, bool? isLoginInProgress, String? returnPath}) {
    return LoginState(
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
      isLoginInProgress: isLoginInProgress ?? this.isLoginInProgress,
      returnPath: returnPath ?? this.returnPath,
    );
  }
}
