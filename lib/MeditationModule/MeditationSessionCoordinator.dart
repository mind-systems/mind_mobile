import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:meditation_module/meditation_module.dart'
    show IMeditationSessionCoordinator;

class MeditationSessionCoordinator implements IMeditationSessionCoordinator {
  final BuildContext context;

  MeditationSessionCoordinator(this.context);

  @override
  void close() {
    if (!context.mounted) return;
    context.pop();
  }
}
