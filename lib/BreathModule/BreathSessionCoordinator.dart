import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/BreathModule/Presentation/BreathSession/IBreathSessionCoordinator.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/BreathSessionConstructorScreen.dart';

class BreathSessionCoordinator implements IBreathSessionCoordinator {
  final BuildContext context;

  BreathSessionCoordinator(this.context);

  @override
  void openConstructor(String sessionId) {
    if (!context.mounted) return;
    context.push(BreathSessionConstructorScreen.path, extra: sessionId);
  }
}
