import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:breath_module/breath_module.dart' show BreathSessionScreen, IBreathSessionListCoordinator;

class BreathSessionListCoordinator implements IBreathSessionListCoordinator {
  final BuildContext context;

  BreathSessionListCoordinator(this.context);

  @override
  void openSession(String sessionId) {
    context.push(BreathSessionScreen.path, extra: sessionId);
  }
}
