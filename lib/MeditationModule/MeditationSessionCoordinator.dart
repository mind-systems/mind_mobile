import 'package:flutter/widgets.dart';
import 'package:meditation_module/meditation_module.dart'
    show IMeditationSessionCoordinator;

class MeditationSessionCoordinator implements IMeditationSessionCoordinator {
  final BuildContext context;

  MeditationSessionCoordinator(this.context);

  @override
  Future<void> onSessionStopped() async {
    // Placeholder — full implementation (push MeditationNoteScreen, persist note)
    // arrives in the meditation-notes wiring milestone (ROADMAP line 78).
  }
}
