import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/BreathSessionListScreen.dart';
import 'package:mind/Views/ComingSoonScreen.dart';
import 'IHomeCoordinator.dart';

class HomeCoordinator implements IHomeCoordinator {
  final BuildContext context;
  HomeCoordinator(this.context);

  @override
  void openBreath() => context.push(BreathSessionListScreen.path);

  @override
  void openComingSoon() => context.push(ComingSoonScreen.path);
}
