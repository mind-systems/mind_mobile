# Meditation Notes — Copy Proto and Regenerate Dart Stubs

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- Standard proto-copy task: copy `meditation_notes.proto` from the API repo, regenerate stubs, verify the client class appears — no application code changes.
- The generated `MeditationNotesServiceClient` is consumed by the next task (`MeditationNotesGrpcApi`); this task only makes it available.

## Details

### Steps

```bash
cp mind_api/proto/meditation_notes.proto mind_mobile/proto/
cd mind_mobile
./scripts/gen_proto.sh
```

Verify `MeditationNotesServiceClient` (or the exact class name produced by the script) appears under `lib/Core/Grpc/generated/`. Check `lib/Core/Grpc/GrpcClient.dart` for the getter name that exposes the new service — that name is needed by the next task (`grpcClient.<meditationNotesService>`).

### Proto contract (for reference)

```proto
message MeditationNote {
  string id         = 1;
  string session_id = 2;  // empty string if detached
  string pose_name  = 3;
  string note_text  = 4;
  string created_at = 5;  // ISO-8601
  string updated_at = 6;  // ISO-8601
  // no user_id — client knows its own identity
}

message CreateNoteRequest {
  string session_id = 1;
  string pose_name  = 2;
  string note_text  = 3;
}

message UpdateNoteRequest {
  string note_id   = 1;
  string note_text = 2;
}

message ListNotesRequest  { int32 page_size = 1; string page_token = 2; }
message ListNotesResponse { repeated MeditationNote notes = 1; string next_page_token = 2; }

service MeditationNotesService {
  rpc CreateNote(CreateNoteRequest) returns (MeditationNote);
  rpc UpdateNote(UpdateNoteRequest) returns (MeditationNote);  // future use — not wired yet
  rpc ListNotes(ListNotesRequest)   returns (ListNotesResponse);
}
```

Timestamps are ISO-8601 strings. `ALREADY_EXISTS` returned if `CreateNote` called twice for the same `session_id`.

### Verify

Project compiles with `flutter pub get && flutter build apk --flavor dev -t lib/main_dev.dart` (or just `flutter analyze`). No runtime test needed — the client is not wired anywhere yet.
