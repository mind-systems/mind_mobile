abstract class IModuleSessionNoteService {
  Future<void> saveNote(String text, {String? sessionId});
}
