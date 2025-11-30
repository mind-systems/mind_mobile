class LoginState {
  final String email;
  final bool isLoading;
  final String returnPath;

  const LoginState({
    this.email = '',
    this.isLoading = false,
    this.returnPath = '/',
  });

  LoginState copyWith({String? email, bool? isLoading, String? returnPath}) {
    return LoginState(
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
      returnPath: returnPath ?? this.returnPath,
    );
  }
}
