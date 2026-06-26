import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/MeditationModule/IModuleSessionNoteService.dart';
import 'package:mind/MeditationModule/ModuleSessionNoteRepository.dart';

class ModuleSessionNoteService implements IModuleSessionNoteService {
  final ModuleSessionNoteRepository _repository;

  ModuleSessionNoteService(ModuleSessionNoteRepository repository)
      : _repository = repository;

  @override
  Future<void> saveNote(String text, {String? sessionId}) async {
    await _repository.save(text, serverSessionId: sessionId);
    if (sessionId != null) {
      unawaited(_syncToServer(sessionId, text.trim()));
    }
  }

  Future<void> _syncToServer(String sessionId, String noteText) async {
    try {
      await App.shared.meditationNotesGrpcApi.createNote(
        sessionId: sessionId,
        poseId: '',
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
