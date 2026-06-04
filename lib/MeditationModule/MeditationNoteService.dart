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
  }
}
