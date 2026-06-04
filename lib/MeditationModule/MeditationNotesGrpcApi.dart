import 'package:mind/Core/Grpc/generated/meditation_notes.pbgrpc.dart';

class MeditationNotesGrpcApi {
  final MeditationNotesServiceClient _client;

  MeditationNotesGrpcApi(this._client);

  Future<void> createNote({
    required String sessionId,
    required String poseId,
    required String noteText,
  }) async {
    await _client.createNote(CreateNoteRequest(
      sessionId: sessionId,
      poseId: poseId,
      noteText: noteText,
    ));
  }
}
