# Module Session Notes — Local Data Layer Rename

**Date:** 2026-06-25
**Source:** conversation context

## Key Findings

- Rename all local (Drift + domain) classes from `MeditationNote*` to `ModuleSessionNote*`; the gRPC adapter (`MeditationNotesGrpcApi`) is renamed in a separate task (note 12).
- Remove `poseId` from the Drift table and from all method signatures — the pose is already captured in `module_sessions.activityRefId` on the backend; it is redundant locally.
- Schema version 5 → 6: drop `meditation_notes`, create `module_session_notes` (without `poseId`); existing data is intentionally not migrated.
- Until note 12 lands, `ModuleSessionNoteService._syncToServer` must bridge to the old gRPC adapter by passing `poseId: ''` explicitly.

## Details

### Files to rename / change

| Old path | New path | Notes |
|---|---|---|
| `lib/Core/Database/MeditationNotesDao.dart` | `lib/Core/Database/ModuleSessionNotesDao.dart` | Rename table class `MeditationNotes` → `ModuleSessionNotes`; rename DAO class `MeditationNotesDao` → `ModuleSessionNotesDao`; drop `poseId` column |
| `lib/MeditationModule/IMeditationNoteService.dart` | `lib/MeditationModule/IModuleSessionNoteService.dart` | Rename interface `IMeditationNoteService` → `IModuleSessionNoteService`; signature unchanged |
| `lib/MeditationModule/MeditationNoteRepository.dart` | `lib/MeditationModule/ModuleSessionNoteRepository.dart` | Rename class; change `save(String poseId, String text, ...)` → `save(String text, ...)`; update `MeditationNotesCompanion.insert` call (no `poseId:` arg) |
| `lib/MeditationModule/MeditationNoteService.dart` | `lib/MeditationModule/ModuleSessionNoteService.dart` | Rename class; drop `_poseSlug` field + constructor arg; update `saveNote` (no poseId lookup); `_syncToServer(sessionId, text)` — still calls `App.shared.meditationNotesGrpcApi.createNote(sessionId:, poseId: '', noteText:)` as bridge |

### `Database.dart` changes

```dart
// remove:
part 'MeditationNotesDao.dart';

// add:
part 'ModuleSessionNotesDao.dart';

// @DriftDatabase annotation: replace MeditationNotes/MeditationNotesDao
@DriftDatabase(
  tables: [UserRecord, BreathSessions, SyncState, MeditationPoses, ModuleSessionNotes],
  daos: [UserDao, BreathSessionDao, SyncStateDao, MeditationPosesDao, ModuleSessionNotesDao],
)

// schemaVersion:
int get schemaVersion => 6;

// migration step 5:
if (step == 5) {
  await customStatement('DROP TABLE IF EXISTS meditation_notes');
  await migrator.createTable(moduleSessionNotes);
}
```

### `App.dart` changes

- Line 59–60: replace imports for `MeditationNotesGrpcApi` and `MeditationNoteRepository` — only the Repository import changes (GrpcApi unchanged until note 12).
- Lines 112–113: rename fields:
  - `late final MeditationNoteRepository meditationNoteRepository` → `late final ModuleSessionNoteRepository moduleSessionNoteRepository`
- Line 268–269: rename initialization (GrpcApi line untouched until note 12):
  - `shared.meditationNoteRepository = MeditationNoteRepository(dao: db.moduleSessionNotesDao)`

### `MeditationModule.dart` changes

- Line 9: update import for `MeditationNoteService` → `ModuleSessionNoteService`
- Line 54: `noteService: ModuleSessionNoteService(App.shared.moduleSessionNoteRepository)`

### `MeditationSessionCoordinator.dart` changes

- Update import for `IMeditationNoteService` → `IModuleSessionNoteService`
- Update type of `noteService` field

### Regenerate Drift code

```bash
flutter pub run build_runner build
```

`Database.g.dart` is auto-generated — do not edit manually.

### Bridge note

`ModuleSessionNoteService._syncToServer` still calls `App.shared.meditationNotesGrpcApi` (old name) with `poseId: ''`. This is intentional — it compiles, the server ignores the empty `pose_id` field (proto3 default). The GrpcApi rename + `poseId` removal happens in note 12.
