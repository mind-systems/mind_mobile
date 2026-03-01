import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/UserNotifier.dart';
import 'package:mind/User/Presentation/Login/ILoginService.dart';

class LoginService implements ILoginService {
  final UserNotifier userNotifier;

  LoginService({required this.userNotifier});

  @override
  Stream<AuthState> observeAuthState() => userNotifier.stream;

  @override
  Future<void> sendPasswordlessSignInLink(String email) async {
    await userNotifier.sendPasswordlessSignInLink(email);
  }

  @override
  Future<void> loginWithGoogle() async {
    await userNotifier.loginWithGoogle();
  }

  @override
  Stream<bool> observeAuthInProgress() => userNotifier.authInProgressStream;
}
