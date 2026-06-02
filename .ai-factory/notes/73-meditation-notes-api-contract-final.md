# Meditation Notes — Final API Contract and Mobile Delta

**Date:** 2026-06-02
**Source:** API design session

## Key Findings

- Proto contract changed vs. notes 67 and 72 — do NOT implement against the old spec.
- `CreateOrUpdateNote` split into `CreateNote` (create) + `UpdateNote` (future edit, not wired yet).
- `pose_id` renamed to `pose_name` everywhere (proto, Drift table, repository, GrpcApi).
- Timestamps changed: `int64` unix ms → ISO-8601 strings (`string created_at / updated_at`).
- Server enforces one note per session (unique constraint); `CreateNote` returns `ALREADY_EXISTS` if called twice — handle in fire-and-forget error logger.

## Final Proto Contract

```proto
message MeditationNote {
  string id         = 1;
  string session_id = 2;  // empty string if detached
  string pose_name  = 3;
  string note_text  = 4;
  string created_at = 5;  // ISO-8601, e.g. "2026-06-02T10:00:00.000Z"
  string updated_at = 6;  // ISO-8601
  // no user_id — client knows its own identity
}

message CreateNoteRequest {
  string session_id = 1;
  string pose_name  = 2;
  string note_text  = 3;
}

// Only note_text is mutable after creation.
message UpdateNoteRequest {
  string note_id   = 1;
  string note_text = 2;
}

message ListNotesRequest  { int32 page_size = 1; string page_token = 2; }
message ListNotesResponse { repeated MeditationNote notes = 1; string next_page_token = 2; }

service MeditationNotesService {
  rpc CreateNote(CreateNoteRequest) returns (MeditationNote);
  rpc UpdateNote(UpdateNoteRequest) returns (MeditationNote);  // future use — not wired in mobile yet
  rpc ListNotes(ListNotesRequest)   returns (ListNotesResponse);
}
```

Wait for the final `meditation_notes.proto` from the API repo before regenerating stubs.

## What Changes vs. Notes 67 and 72

### 1. RPC rename: `CreateOrUpdateNote` → `CreateNote`

Old (notes 67, 72):
```dart
_client.createOrUpdateNote(CreateOrUpdateNoteRequest(...))
```

New:
```dart
_client.createNote(CreateNoteRequest(
  sessionId: sessionId,
  poseName: poseName,   // renamed field
  noteText: noteText,
))
```

### 2. `pose_id` → `pose_name` everywhere

**Drift table** (`lib/Core/Database/MeditationNotesTable.dart` or `AppDatabase.dart`):
```dart
// OLD
TextColumn get poseId => text()();

// NEW
TextColumn get poseName => text()();
```

Run `flutter pub run build_runner build` after the rename to regenerate Drift companions.

**MeditationNoteRepository** (`lib/MeditationModule/MeditationNoteRepository.dart`):
```dart
// OLD
Future<void> save(String poseId, String text, {String? serverSessionId})

// NEW
Future<void> save(String poseName, String text, {String? serverSessionId})
```

Update the `insert` call accordingly (`poseName: poseName`).

**MeditationNoteService** (`lib/MeditationModule/MeditationNoteService.dart`):
Replace `_poseId` field with `_poseName`. Pass `poseName:` to `_api.createNote` and `_repository.save`.

**MeditationNotesGrpcApi** (`lib/MeditationModule/MeditationNotesGrpcApi.dart`):
```dart
// OLD
Future<void> createOrUpdateNote({
  required String sessionId,
  required String poseId,
  required String noteText,
})

// NEW
Future<void> createNote({
  required String sessionId,
  required String poseName,
  required String noteText,
})
```

### 3. Timestamp type change

Old notes said `int64` — **ignore that**, it was corrected. The final contract uses ISO-8601 strings.

If `MeditationNote.createdAt` is ever displayed or stored locally, parse with `DateTime.parse(note.createdAt)` (not `DateTime.fromMillisecondsSinceEpoch`). For now, if mobile just stores the raw note response in Drift and doesn't display server timestamps, this may have no immediate impact — but the parse path must be correct when history screen is built.

### 4. `ALREADY_EXISTS` on duplicate create

The server enforces one note per `session_id` (unique DB constraint). If `CreateNote` is called twice for the same session (e.g. retry after network hiccup), the second call returns `ALREADY_EXISTS`. The fire-and-forget error logger should treat this as a non-fatal error — the note was already saved.

```dart
unawaited(
  _api.createNote(...).catchError((e) {
    // ALREADY_EXISTS is non-fatal — note already on server
    dev.log('createNote failed: $e', name: 'MeditationNote');
  }),
);
```

### 5. `UpdateNote` — exists but not wired yet

A separate `UpdateNote(note_id, note_text)` RPC is available for future note editing. Mobile has no editing UI yet — skip wiring it for now. The note's UUID is returned in `CreateNote` response if needed later.

## What Stays the Same

- Session-ID capture via `_channelSub` in `MeditationModuleStateChannel` (see note 67 §Step 2) — no change.
- Coordinator → `getSessionId` closure pattern (note 67 §Step 5-6) — no change.
- Local-first save: Drift insert happens before the gRPC call — no change.
- Fire-and-forget pattern with `unawaited` + `catchError` — no change.
- Proto copy workflow: `cp mind_api/proto/meditation_notes.proto mind_mobile/proto/` + `./scripts/gen_proto.sh` — same process, different file content.

## Action Summary

| Item | Action |
|------|--------|
| Wait for `meditation_notes.proto` from API repo | Block proto copy until API team confirms |
| Copy proto + regenerate stubs | Replace note 72 flow; expect `CreateNote` / `UpdateNote` / `ListNotes` |
| Drift table column `poseId` → `poseName` | If already migrated, add a Drift migration step |
| `MeditationNoteRepository.save` signature | Rename `poseId` param to `poseName` |
| `MeditationNotesGrpcApi` | Rename method + param (`createNote`, `poseName`) |
| `MeditationNoteService` | Rename internal field `_poseName` |
| Timestamp parsing | Use `DateTime.parse()` not `fromMillisecondsSinceEpoch` |
| `UpdateNote` | Skip for now — no mobile UI |
