import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bci_module/bci_module.dart' show BciDataScreen;
import 'package:breath_module/breath_module.dart' show BreathSessionListScreen, BreathSessionScreen;
import 'package:meditation_module/meditation_module.dart' show MeditationListScreen;
import 'package:mind/ProfileModule/Presentation/ProfileScreen/ProfileScreen.dart';
import 'IHomeCoordinator.dart';

class HomeCoordinator implements IHomeCoordinator {
  final BuildContext context;
  HomeCoordinator(this.context);

  @override
  void openBreath() => context.push(BreathSessionListScreen.path);

  @override
  void openMeditation() => context.push(MeditationListScreen.path);

  @override
  void openComingSoon() => context.push(BciDataScreen.path);

  @override
  void openProfile() => context.push(ProfileScreen.path);

  @override
  void openSuggestion(String sessionId) => context.push(BreathSessionScreen.path, extra: sessionId);
}
