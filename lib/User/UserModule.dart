import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/User/Presentation/Login/LoginScreen.dart';
import 'package:mind/User/Presentation/Login/LoginService.dart';
import 'package:mind/User/Presentation/Login/LoginViewModel.dart';
import 'package:mind/User/Presentation/Login/OnboardingScreen.dart';

class UserModule {
  static Widget buildOnboarding(BuildContext context, {required String returnPath}) {
    final service = LoginService(userNotifier: App.shared.userNotifier);
    return ProviderScope(
      overrides: [
        loginViewModelProvider.overrideWith(
          (ref) => LoginViewModel(service: service, returnPath: returnPath),
        ),
      ],
      child: const OnboardingScreen(),
    );
  }

  static Widget buildLogin(BuildContext context, {required String returnPath}) {
    final service = LoginService(userNotifier: App.shared.userNotifier);
    return ProviderScope(
      overrides: [
        loginViewModelProvider.overrideWith(
          (ref) => LoginViewModel(service: service, returnPath: returnPath),
        ),
      ],
      child: const LoginScreen(),
    );
  }
}
