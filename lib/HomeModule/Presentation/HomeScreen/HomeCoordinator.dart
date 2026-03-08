import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/BreathSessionListScreen.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/ProfileModule/Presentation/ProfileScreen/ProfileScreen.dart';
import 'package:mind/User/Models/AuthState.dart';
import 'package:mind/User/Presentation/Login/OnboardingScreen.dart';
import 'package:mind/Views/ComingSoonScreen.dart';
import 'IHomeCoordinator.dart';

class HomeCoordinator implements IHomeCoordinator {
  final BuildContext context;
  HomeCoordinator(this.context);

  @override
  void openBreath() => context.push(BreathSessionListScreen.path);

  @override
  void openComingSoon() => context.push(ComingSoonScreen.path);

  @override
  void openProfile() {
    final authState = App.shared.userNotifier.currentState;
    if (authState is GuestState) {
      context.push(OnboardingScreen.path, extra: ProfileScreen.path);
    } else {
      context.push(ProfileScreen.path);
    }
  }
}
