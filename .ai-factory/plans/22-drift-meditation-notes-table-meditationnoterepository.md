# Plan: Drift `meditation_notes` table + `MeditationNoteRepository`

## Context
Add local persistence for meditation notes via a new Drift table and a `MeditationNoteRepository` that generates a local UUID and inserts rows, wired into the `App` DI singleton.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Conventions & Notes
- The Drift database class is `Database` in `lib/Core/Database/Database.dart` (the milestone's "`AppDatabase`" refers to this `@DriftDatabase` class). Tables + DAOs follow the `part of 'Database.dart'` split-file pattern — see `lib/Core/Database/MeditationPosesDao.dart` as the reference template.
- Table class naming follows existing convention (plural noun, no `Table` suffix): `BreathSessions`, `MeditationPoses`, `SyncState`. This plan names the table class `MeditationNotes` for consistency (the milestone's "`MeditationNotesTable`" maps to this).
- Column contract comes from spec `.ai-factory/notes/88-meditation-notes-pose-id-rename.md`: `poseId` stores the pose **UUID** (`meditation_poses.id`), not the slug. No FK, no cascade delete.
- `uuid: ^4.5.3` is already in `pubspec.yaml` — guard satisfied, no dependency change needed.

## Tasks

### Phase 1: Drift table + DAO

- [x] **Task 1: Create `MeditationNotes` table + `MeditationNotesDao` part file**
  Files: `lib/Core/Database/MeditationNotesDao.dart`
  Create a new part file (`part of 'Database.dart';`) mirroring `MeditationPosesDao.dart`. Define table `MeditationNotes` with `@DataClassName('MeditationNoteRow')` and columns:
  - `TextColumn get id => text()();` — primary key (`@override Set<Column> get primaryKey => {id};`)
  - `TextColumn get poseId => text()();` — stores the pose UUID (`meditation_poses.id`)
  - `TextColumn get noteText => text()();`
  - `IntColumn get createdAt => integer()();` — unix milliseconds
  - `TextColumn get serverSessionId => text().nullable()();`
  No FK / no cascade delete.
  Add `@DriftAccessor(tables: [MeditationNotes])` class `MeditationNotesDao extends DatabaseAccessor<Database> with _$MeditationNotesDaoMixin`, constructor `MeditationNotesDao(super.db);`, and a single insert method, e.g. `Future<void> insertNote(MeditationNotesCompanion entry) => into(meditationNotes).insert(entry);`.

- [x] **Task 2: Register table/DAO in `Database` and bump schema version** (depends on Task 1)
  Files: `lib/Core/Database/Database.dart`
  - Add `part 'MeditationNotesDao.dart';` alongside the other `part` directives.
  - Add `MeditationNotes` to the `@DriftDatabase(tables: [...])` list and `MeditationNotesDao` to `daos: [...]`.
  - Bump `schemaVersion` from `4` to `5`.
  - In `migration.onUpgrade`, add `if (step == 4) { await migrator.createTable(meditationNotes); }` following the existing stepwise pattern. (Fresh installs are covered by Drift's default `createAll`.)

- [x] **Task 3: Regenerate Drift code** (depends on Task 2)
  Files: `lib/Core/Database/Database.g.dart` (generated)
  Run `/usr/local/bin/flutter pub run build_runner build --delete-conflicting-outputs`. Confirm generated `MeditationNoteRow`, `MeditationNotesCompanion`, and `db.meditationNotesDao` accessor compile.

### Phase 2: Repository + DI wiring

- [x] **Task 4: Create `MeditationNoteRepository`** (depends on Task 3)
  Files: `lib/MeditationModule/MeditationNoteRepository.dart`
  Pure-Dart repository (no Flutter/Riverpod imports). Take the DAO via constructor, mirroring `BreathSessionRepository(dao: ...)`:
  ```dart
  class MeditationNoteRepository {
    final MeditationNotesDao _dao;
    MeditationNoteRepository({required MeditationNotesDao dao}) : _dao = dao;

    Future<void> save(String poseId, String text, {String? serverSessionId}) async {
      final id = const Uuid().v4();
      await _dao.insertNote(MeditationNotesCompanion.insert(
        id: id,
        poseId: poseId,
        noteText: text,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        serverSessionId: Value(serverSessionId),
      ));
    }
  }
  ```
  Import `package:uuid/uuid.dart`, `package:drift/drift.dart` (for `Value`), and the Database part types. Keep `createdAt` as unix ms.

- [x] **Task 5: Wire `meditationNoteRepository` into `App`** (depends on Task 4)
  Files: `lib/Core/App.dart`
  - Add import for `MeditationNoteRepository`.
  - Declare `late final MeditationNoteRepository meditationNoteRepository;` as an `App` field (mirror the existing `late final MeditationPosesGrpcApi meditationPosesApi;` post-construction pattern — do NOT add it to the `App._` required constructor).
  - In `initialize()`, after `shared = App._(...)`, assign `shared.meditationNoteRepository = MeditationNoteRepository(dao: db.meditationNotesDao);` near the `shared.meditationPosesApi = ...` line. Respect the file's style rule: single-line initializer, no trailing comma.

## Commit Plan
- **Commit 1** (after tasks 1-3): "Add meditation_notes Drift table and DAO"
- **Commit 2** (after tasks 4-5): "Add MeditationNoteRepository and wire into App"
