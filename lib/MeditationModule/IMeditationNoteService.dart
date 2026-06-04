abstract class IMeditationNoteService {
  Future<void> saveNote(String text, {String? sessionId});
}
