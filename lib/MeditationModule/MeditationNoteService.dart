import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/MeditationModule/IMeditationNoteService.dart';
import 'package:mind/MeditationModule/MeditationNoteRepository.dart';

class MeditationNoteService implements IMeditationNoteService {
  final String _poseSlug;
  final MeditationNoteRepository _repository;

  MeditationNoteService(String poseSlug, MeditationNoteRepository repository)
      : _poseSlug = poseSlug,
        _repository = repository;

  @override
  Future<void> saveNote(String text, {String? sessionId}) async {
    final poseId = App.shared.meditationPoseUuids[_poseSlug] ?? _poseSlug;
    await _repository.save(poseId, text, serverSessionId: sessionId);
    if (sessionId != null) {
      unawaited(_syncToServer(sessionId, poseId, text.trim()));
    }
  }

  Future<void> _syncToServer(String sessionId, String poseId, String noteText) async {
    try {
      await App.shared.meditationNotesGrpcApi.createNote(
        sessionId: sessionId,
        poseId: poseId,
        noteText: noteText,
      );
    } on GrpcError catch (e) {
      if (e.code == StatusCode.alreadyExists) return;
      // non-fatal — sync failure does not surface to the caller
    } catch (_) {
      // non-fatal — sync failure does not surface to the caller
    }
  }
}
