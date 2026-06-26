import 'package:mind/Core/Grpc/generated/module_session_notes.pbgrpc.dart';

class ModuleSessionNotesGrpcApi {
  final ModuleSessionNotesServiceClient _client;

  ModuleSessionNotesGrpcApi(this._client);

  Future<void> createNote({
    required String sessionId,
    required String noteText,
  }) async {
    await _client.createNote(CreateNoteRequest(
      sessionId: sessionId,
      noteText: noteText,
    ));
  }
}
