import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meditation_module/meditation_module.dart'
    show IMeditationSessionCoordinator, MeditationNoteScreen;
import 'package:mind/MeditationModule/IMeditationNoteService.dart';

class MeditationSessionCoordinator implements IMeditationSessionCoordinator {
  MeditationSessionCoordinator(
    this.context, {
    required this.noteService,
    required this.getSessionId,
  });

  final BuildContext context;
  final IMeditationNoteService noteService;
  final String? Function() getSessionId;

  @override
  Future<void> onSessionStopped() async {
    if (!context.mounted) return;
    final text = await Navigator.of(context).push<String?>(
      MaterialPageRoute(builder: (_) => const MeditationNoteScreen()),
    );
    final trimmed = text?.trim() ?? '';
    if (trimmed.isEmpty) return;
    unawaited(noteService.saveNote(trimmed, sessionId: getSessionId()));
  }
}
