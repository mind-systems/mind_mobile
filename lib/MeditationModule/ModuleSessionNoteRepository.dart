import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:mind/Core/Database/Database.dart';

class ModuleSessionNoteRepository {
  final ModuleSessionNotesDao _dao;

  ModuleSessionNoteRepository({required ModuleSessionNotesDao dao}) : _dao = dao;

  Future<void> save(String text, {String? serverSessionId}) async {
    final id = const Uuid().v4();
    await _dao.insertNote(ModuleSessionNotesCompanion.insert(
      id: id,
      noteText: text,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      serverSessionId: Value(serverSessionId),
    ));
  }
}
