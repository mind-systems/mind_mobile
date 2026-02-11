import 'package:mind/User/Models/AuthState.dart';

/// Сервис аутентификации для LoginViewModel.
abstract class ILoginService {
  Stream<AuthState> observeAuthState();

  Future<void> sendPasswordlessSignInLink(String email);

  Future<void> loginWithGoogle();
}
