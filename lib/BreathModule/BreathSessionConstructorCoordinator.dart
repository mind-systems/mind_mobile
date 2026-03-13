import 'package:go_router/go_router.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionConstructor/IBreathSessionConstructorCoordinator.dart';
import 'package:flutter/widgets.dart';

class BreathSessionConstructorCoordinator
    implements IBreathSessionConstructorCoordinator {
  final BuildContext context;

  BreathSessionConstructorCoordinator(this.context);

  @override
  void dismiss() {
    if (context.mounted) {
      context.pop();
    }
  }
}
