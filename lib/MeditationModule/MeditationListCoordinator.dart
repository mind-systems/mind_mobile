import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:meditation_module/meditation_module.dart'
    show IMeditationListCoordinator, MeditationSessionScreen;

class MeditationListCoordinator implements IMeditationListCoordinator {
  final BuildContext context;

  MeditationListCoordinator(this.context);

  @override
  void openSession(String poseId) {
    context.push(MeditationSessionScreen.path, extra: poseId);
  }
}
