import 'package:mind/Core/AppSettings/AppSettingsNotifier.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/UserNotifier.dart';
import 'package:mind/User/Presentation/Login/ILoginService.dart';

class LoginService implements ILoginService {
  final UserNotifier userNotifier;
  final AppSettingsNotifier appSettingsNotifier;

  LoginService({required this.userNotifier, required this.appSettingsNotifier});

  @override
  Stream<AuthState> observeAuthState() => userNotifier.stream;

  @override
  Future<void> sendPasswordlessSignInLink(String email) async {
    await userNotifier.sendPasswordlessSignInLink(email, language: appSettingsNotifier.currentState.language);
  }

  @override
  Future<void> completePasswordlessSignIn(String code) async {
    await userNotifier.completePasswordlessSignIn(code, language: appSettingsNotifier.currentState.language);
  }

  @override
  Future<void> loginWithGoogle() async {
    await userNotifier.loginWithGoogle(language: appSettingsNotifier.currentState.language);
  }

  @override
  Stream<bool> observeAuthInProgress() => userNotifier.authInProgressStream;
}
