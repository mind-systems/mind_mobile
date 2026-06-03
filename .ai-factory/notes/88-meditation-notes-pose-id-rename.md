# meditation_notes: poseId (UUID) Instead of poseName (slug)

**Date:** 2026-06-03
**Source:** API Phase 31 — meditation_notes.pose_name renamed to pose_id

## Key Findings

- The server field `meditation_notes.pose_id` stores the pose UUID, not the slug. Mobile must store UUID in the local Drift column and send UUID over gRPC.
- UUID is resolved from `App.shared.meditationPoseUuids[slug]` in `MeditationNoteService` — coordinators and session screen continue to work with the slug.
- Supersedes the `poseName` field contract in notes 65 (Drift table) and 67 (gRPC wire). Implement those tasks using the contracts below.

## Details

### Drift table (`lib/Core/Database/`) — replaces note 65

```dart
// Column name: poseId, not poseName
TextColumn get poseId => text()();   // stores the UUID from meditation_poses.id
```

### `MeditationNoteRepository` — replaces note 65

```dart
Future<void> save(
  String poseId,     // UUID
  String text, {
  String? serverSessionId,
})
```

### `MeditationNoteService` — replaces note 66

Constructor receives the slug (`poseSlug`) and resolves it to UUID internally:
```dart
class MeditationNoteService {
  MeditationNoteService(String poseSlug, MeditationNoteRepository _repo);

  Future<void> saveNote(String text, {String? sessionId}) async {
    final poseId = App.shared.meditationPoseUuids[poseSlug] ?? poseSlug;
    await _repo.save(poseId, text, serverSessionId: sessionId);
    // gRPC fire-and-forget wired in Phase 28 Task 9
  }
}
```

Keeping the slug in the constructor (not the UUID) allows `MeditationModule.buildSession` to stay unchanged — it still passes `poseId` (slug) to the service, consistent with how it passes `poseId` to the session screen.

### `MeditationNotesGrpcApi.createNote()` — replaces note 67

```dart
createNote({
  required String sessionId,
  required String poseId,    // UUID
  required String noteText,
})
```

### `meditation_notes.proto` field name
The server proto field is `pose_id` (renamed from `pose_name`). The updated `meditation_notes.proto` is in `mind_api/proto/` — copy it to `mind_mobile/proto/` as part of Phase 28 Task 8 and regenerate stubs.
