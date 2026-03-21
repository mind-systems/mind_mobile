import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:breath_module/breath_module.dart' show IBreathSessionCoordinator, BreathSessionConstructorScreen;
import 'package:mind/Core/Handlers/BreathSessionDeeplinkHandler.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Presentation/Login/Models/AuthResult.dart';
import 'package:mind/User/Presentation/Login/OnboardingScreen.dart';
import 'package:mind/User/UserNotifier.dart';
import 'package:share_plus/share_plus.dart';

class BreathSessionCoordinator implements IBreathSessionCoordinator {
  final BuildContext context;
  final UserNotifier userNotifier;

  BreathSessionCoordinator(this.context, {required this.userNotifier});

  @override
  void shareSession(String sessionId) {
    SharePlus.instance.share(ShareParams(text: BreathSessionDeeplinkHandler.buildSessionUrl(sessionId)));
  }

  @override
  void dismiss() {
    if (!context.mounted) return;
    context.pop();
  }

  @override
  void openConstructor(String sessionId) {
    if (!context.mounted) return;
    final authState = userNotifier.currentState;
    if (authState is GuestState) {
      context.push<AuthResult>(OnboardingScreen.path).then((result) {
        if (result == AuthResult.success && context.mounted) {
          context.push(BreathSessionConstructorScreen.path, extra: sessionId);
        }
      });
    } else {
      context.push(BreathSessionConstructorScreen.path, extra: sessionId);
    }
  }
}
