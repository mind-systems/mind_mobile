import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/BreathSessionScreen.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/IBreathSessionListCoordinator.dart';

class BreathSessionListCoordinator implements IBreathSessionListCoordinator {
  final BuildContext context;

  BreathSessionListCoordinator(this.context);

  @override
  void openSession(String sessionId) {
    context.push(BreathSessionScreen.path, extra: sessionId);
  }
}
