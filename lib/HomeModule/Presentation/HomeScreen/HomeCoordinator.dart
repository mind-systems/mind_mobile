import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:breath_module/breath_module.dart' show BreathSessionListScreen, BreathSessionScreen;
import 'package:mind/ProfileModule/Presentation/ProfileScreen/ProfileScreen.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Presentation/Login/Models/AuthResult.dart';
import 'package:mind/User/Presentation/Login/OnboardingScreen.dart';
import 'package:mind/User/UserNotifier.dart';
import 'package:mind_ui/mind_ui.dart';
import 'IHomeCoordinator.dart';

class HomeCoordinator implements IHomeCoordinator {
  final BuildContext context;
  final UserNotifier userNotifier;
  HomeCoordinator(this.context, {required this.userNotifier});

  @override
  void openBreath() => context.push(BreathSessionListScreen.path);

  @override
  void openComingSoon() => context.push(ComingSoonScreen.path);

  @override
  void openProfile() {
    final authState = userNotifier.currentState;
    if (authState is GuestState) {
      context.push<AuthResult>(OnboardingScreen.path).then((result) {
        if (result == AuthResult.success && context.mounted) {
          context.push(ProfileScreen.path);
        }
      });
    } else {
      context.push(ProfileScreen.path);
    }
  }

  @override
  void openSuggestion(String sessionId) => context.push(BreathSessionScreen.path, extra: sessionId);
}
