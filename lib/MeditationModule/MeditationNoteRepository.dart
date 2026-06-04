import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:mind/Core/Database/Database.dart';

class MeditationNoteRepository {
  final MeditationNotesDao _dao;

  MeditationNoteRepository({required MeditationNotesDao dao}) : _dao = dao;

  Future<void> save(String poseId, String text, {String? serverSessionId}) async {
    final id = const Uuid().v4();
    await _dao.insertNote(MeditationNotesCompanion.insert(
      id: id,
      poseId: poseId,
      noteText: text,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      serverSessionId: Value(serverSessionId),
    ));
  }
}
