import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:breath_module/breath_module.dart' show BreathSessionScreen, BreathSessionConstructorScreen, IBreathSessionListCoordinator;
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Presentation/Login/Models/AuthResult.dart';
import 'package:mind/User/Presentation/Login/OnboardingScreen.dart';
import 'package:mind/User/UserNotifier.dart';

class BreathSessionListCoordinator implements IBreathSessionListCoordinator {
  final BuildContext context;
  final UserNotifier userNotifier;

  BreathSessionListCoordinator(this.context, {required this.userNotifier});

  @override
  void openSession(String sessionId) {
    context.push(BreathSessionScreen.path, extra: sessionId);
  }

  @override
  void openConstructor() async {
    if (!context.mounted) return;
    if (userNotifier.currentState is GuestState) {
      final result = await context.push<AuthResult>(OnboardingScreen.path);
      if (result == AuthResult.success && context.mounted) {
        context.push(BreathSessionConstructorScreen.path);
      }
    } else {
      context.push(BreathSessionConstructorScreen.path);
    }
  }
}
