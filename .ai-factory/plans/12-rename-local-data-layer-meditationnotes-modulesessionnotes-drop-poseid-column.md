# Plan: Rename local data layer: `MeditationNotes` → `ModuleSessionNotes`, drop `poseId` column

## Context
Rename the local (Drift + domain) notes layer from `MeditationNote*` to `ModuleSessionNote*` and drop the redundant `poseId` column (pose already lives in `module_sessions.activityRefId`). The gRPC adapter rename is deferred to note 12; until then the service bridges to the old adapter with `poseId: ''`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Drift table + DAO rename

- [x] **Task 1: Rename DAO file and table/DAO classes, drop `poseId`**
  Files: create `lib/Core/Database/ModuleSessionNotesDao.dart`, delete `lib/Core/Database/MeditationNotesDao.dart`
  Create `ModuleSessionNotesDao.dart` as `part of 'Database.dart';`. Rename table class `MeditationNotes` → `ModuleSessionNotes`, keep `@DataClassName` but rename `MeditationNoteRow` → `ModuleSessionNoteRow`. Remove the `TextColumn get poseId => text()();` column. Keep columns `id`, `noteText`, `createdAt`, `serverSessionId` and primary key `{id}`. Rename DAO class `MeditationNotesDao` → `ModuleSessionNotesDao`, mixin `_$MeditationNotesDaoMixin` → `_$ModuleSessionNotesDaoMixin`, `@DriftAccessor(tables: [ModuleSessionNotes])`, and update `insertNote` to `into(moduleSessionNotes).insert(entry)` taking a `ModuleSessionNotesCompanion`. Delete the old `MeditationNotesDao.dart` file.

- [x] **Task 2: Update `Database.dart` schema, part directive, annotation, migration**
  Files: `lib/Core/Database/Database.dart`
  Replace `part 'MeditationNotesDao.dart';` → `part 'ModuleSessionNotesDao.dart';`. In `@DriftDatabase`, replace `MeditationNotes` → `ModuleSessionNotes` in `tables` and `MeditationNotesDao` → `ModuleSessionNotesDao` in `daos`. Bump `schemaVersion` 5 → 6. Add migration step 5 inside the `onUpgrade` loop:
  ```dart
  if (step == 5) {
    await customStatement('DROP TABLE IF EXISTS meditation_notes');
    await migrator.createTable(moduleSessionNotes);
  }
  ```
  Leave existing steps 1–4 untouched (step 4 still references `meditationNotes` — but that table class is being removed, so update step 4 to also use the new table: `await migrator.createTable(moduleSessionNotes);`). Note: step 4 created `meditationNotes`; since the class no longer exists, change step 4's `createTable(meditationNotes)` → `createTable(moduleSessionNotes)` so fresh-from-v4 upgrades still compile and create the renamed table.

### Phase 2: Domain layer rename + `poseId` removal

- [x] **Task 3: Rename repository, drop `poseId` param** (depends on Task 1)
  Files: create `lib/MeditationModule/ModuleSessionNoteRepository.dart`, delete `lib/MeditationModule/MeditationNoteRepository.dart`
  Rename class `MeditationNoteRepository` → `ModuleSessionNoteRepository`. Change field/ctor type `MeditationNotesDao` → `ModuleSessionNotesDao`. Change `save(String poseId, String text, {String? serverSessionId})` → `save(String text, {String? serverSessionId})`. Update the insert to `ModuleSessionNotesCompanion.insert(id: id, noteText: text, createdAt: ..., serverSessionId: Value(serverSessionId))` — no `poseId:` argument.

- [x] **Task 4: Rename service interface**
  Files: create `lib/MeditationModule/IModuleSessionNoteService.dart`, delete `lib/MeditationModule/IMeditationNoteService.dart`
  Rename `IMeditationNoteService` → `IModuleSessionNoteService`. Method signature `saveNote(String text, {String? sessionId})` unchanged.

- [x] **Task 5: Rename service, drop `_poseSlug`, bridge to old gRPC adapter** (depends on Task 3, Task 4)
  Files: create `lib/MeditationModule/ModuleSessionNoteService.dart`, delete `lib/MeditationModule/MeditationNoteService.dart`
  Rename class `MeditationNoteService` → `ModuleSessionNoteService` implementing `IModuleSessionNoteService`. Remove the `_poseSlug` field and the `poseSlug` constructor argument — constructor becomes `ModuleSessionNoteService(ModuleSessionNoteRepository repository)`. In `saveNote`, drop the `meditationPoseUuids` pose lookup: call `_repository.save(text, serverSessionId: sessionId)` then `unawaited(_syncToServer(sessionId, text.trim()))` when `sessionId != null`. Change `_syncToServer(String sessionId, String noteText)` to still call `App.shared.meditationNotesGrpcApi.createNote(sessionId: sessionId, poseId: '', noteText: noteText)` (bridge to old adapter; deferred to note 12). Keep the existing `GrpcError`/`alreadyExists` swallow logic. Update imports to the new repository/interface paths.

- [x] **Task 6: Update `MeditationSessionCoordinator` import + field type** (depends on Task 4)
  Files: `lib/MeditationModule/MeditationSessionCoordinator.dart`
  Replace import `IMeditationNoteService.dart` → `IModuleSessionNoteService.dart`. Change field type `IMeditationNoteService noteService` → `IModuleSessionNoteService noteService`.

### Phase 3: Wiring

- [x] **Task 7: Update `App.dart` imports, fields, initialization** (depends on Task 3)
  Files: `lib/Core/App.dart`
  Line 60: change import `MeditationNoteRepository.dart` → `ModuleSessionNoteRepository.dart` (leave the `MeditationNotesGrpcApi` import on line 59 untouched — deferred to note 12). Line 115: `late final MeditationNoteRepository meditationNoteRepository;` → `late final ModuleSessionNoteRepository moduleSessionNoteRepository;`. Line 273: `shared.meditationNoteRepository = MeditationNoteRepository(dao: db.meditationNotesDao);` → `shared.moduleSessionNoteRepository = ModuleSessionNoteRepository(dao: db.moduleSessionNotesDao);`. Leave the `meditationNotesGrpcApi` field/init (lines 114, 272) untouched.

- [x] **Task 8: Update `MeditationModule.dart` wiring** (depends on Task 5, Task 7)
  Files: `lib/MeditationModule/MeditationModule.dart`
  Line 9: change import `MeditationNoteService.dart` → `ModuleSessionNoteService.dart`. Line 54: replace `noteService: MeditationNoteService(poseId, App.shared.meditationNoteRepository)` → `noteService: ModuleSessionNoteService(App.shared.moduleSessionNoteRepository)` (drop the `poseId` arg now that the service no longer takes a pose slug).

### Phase 4: Codegen

- [x] **Task 9: Regenerate Drift code** (depends on Task 1, Task 2)
  Files: `lib/Core/Database/Database.g.dart` (generated)
  Run `flutter pub run build_runner build --delete-conflicting-outputs` (use full Flutter path `/usr/local/bin/flutter`). Confirm `Database.g.dart` regenerates with `ModuleSessionNotes`/`ModuleSessionNotesDao`/`moduleSessionNotes` and no `poseId`. Do not edit the generated file manually. Verify `flutter analyze` is clean for the touched files.

## Commit Plan
- **Commit 1** (after tasks 1-2): "Rename meditation notes Drift table to module session notes and drop poseId"
- **Commit 2** (after tasks 3-6): "Rename meditation note domain layer to module session note"
- **Commit 3** (after tasks 7-9): "Wire module session note layer and regenerate Drift code"
