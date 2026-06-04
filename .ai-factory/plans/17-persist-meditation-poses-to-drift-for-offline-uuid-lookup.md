# Plan: Persist meditation poses to Drift for offline UUID lookup

## Context
Implements **ROADMAP line 61** ("Persist meditation poses to Drift for offline UUID lookup", Phase 33). Spec: `.ai-factory/notes/101-meditation-poses-drift-persistence.md`.

Persist the slug→UUID meditation pose catalogue to a Drift table so the in-memory `meditationPoseUuids` cache can be pre-populated on cold start, preventing the offline UUID crash when starting a meditation session.

**Scope caveat (mitigation, not elimination):** this fix only protects launches that have been online at least once. On a first-ever launch with no connectivity, Drift is empty, `refresh()` fails silently, the map stays `{}`, and `meditationPoseUuids[slug] ?? slug` returns the slug → the UUID crash persists for that single offline session. Eliminating that would require bundled seed data, which is out of scope here. State this so QA isn't surprised.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Drift table + DAO

- [x] **Task 1: Add MeditationPoses table + MeditationPosesDao**
  Files: `lib/Core/Database/MeditationPosesDao.dart`
  Create a new file using the `part of 'Database.dart';` pattern — **match the existing convention** in `SyncStateDao.dart` / `BreathSessionDao.dart` (NOT the standalone-import style shown in the spec; those files have no top-level imports and rely on the generated mixin from `Database.g.dart`).
  - Declare the table:
    ```dart
    @DataClassName('MeditationPoseRow')
    class MeditationPoses extends Table {
      TextColumn get id => text()();
      TextColumn get slug => text()();
      IntColumn get displayOrder => integer()();

      @override
      Set<Column> get primaryKey => {id};
    }
    ```
  - Declare the DAO:
    ```dart
    @DriftAccessor(tables: [MeditationPoses])
    class MeditationPosesDao extends DatabaseAccessor<Database>
        with _$MeditationPosesDaoMixin {
      MeditationPosesDao(super.db);

      Future<List<MeditationPoseRow>> getAll() =>
          (select(meditationPoses)..orderBy([(t) => OrderingTerm.asc(t.displayOrder)])).get();

      Future<void> saveAll(List<({String id, String slug, int displayOrder})> poses) =>
          batch((b) {
            b.insertAllOnConflictUpdate(
              meditationPoses,
              poses.map((p) => MeditationPosesCompanion(
                id: Value(p.id),
                slug: Value(p.slug),
                displayOrder: Value(p.displayOrder),
              )).toList(),
            );
          });
    }
    ```
  - **Guard:** `saveAll` is upsert-only (`insertAllOnConflictUpdate`). No delete logic — rows are never removed. (Note: `batch`/`insertAllOnConflictUpdate` is new to this codebase — existing DAOs use single-row `insertOnConflictUpdate`. Both are valid Drift APIs; a plain loop would also work if you prefer local consistency.)

- [x] **Task 2: Register table + DAO in Database.dart and bump schema to 4** (depends on Task 1)
  Files: `lib/Core/Database/Database.dart`
  - Add `part 'MeditationPosesDao.dart';` alongside the existing `part` directives.
  - Add `MeditationPoses` to the `tables:` list and `MeditationPosesDao` to the `daos:` list in `@DriftDatabase(...)`.
  - Change `schemaVersion` from `3` to `4`.
  - Add the migration step inside the existing `onUpgrade` `for` loop — **match the existing `if (step == N)` style** (not `if (from < 4)`):
    ```dart
    if (step == 3) {
      await migrator.createTable(meditationPoses);
    }
    ```
  - Registering the DAO here makes Drift generate a `db.meditationPosesDao` getter (exactly like `db.userDao`, `db.breathSessionDao`, `db.syncStateDao`). **Use that generated getter everywhere — do NOT add a separate `meditationPosesDao` field to the `App` singleton** (see Task 5).

- [x] **Task 3: Regenerate Drift code** (depends on Task 2)
  Files: `lib/Core/Database/Database.g.dart` (generated)
  Run `/usr/local/bin/flutter pub run build_runner build --delete-conflicting-outputs` to regenerate `Database.g.dart` with the new table, companion, row class, `_$MeditationPosesDaoMixin`, and the `db.meditationPosesDao` accessor. Do not hand-edit generated code.

### Phase 2: API + service wiring

- [x] **Task 4: Extend MeditationPosesGrpcApi.listPoses() to include displayOrder**
  Files: `lib/MeditationModule/MeditationPosesGrpcApi.dart`
  Change the return type from `List<({String id, String slug})>` to `List<({String id, String slug, int displayOrder})>` and map `displayOrder: p.displayOrder` from the proto response (`display_order` is field 3 in `proto/meditation_poses.proto`; the generated `meditation_poses.pb.dart` exposes the `displayOrder` getter). There is no separate `IMeditationPosesGrpcApi` interface — update the concrete class only.

- [x] **Task 5: Pre-populate cache from Drift in App.initialize()** (depends on Task 3)
  Files: `lib/Core/App.dart`
  - **Do NOT add any `meditationPosesDao` field to `App`.** Reach the DAO via the auto-generated `db.meditationPosesDao` getter from Task 2. This is the same way existing code reaches `db.userDao` / `db.syncStateDao` and it avoids the `App.shared` sequencing trap entirely.
  - **Why the ordering matters:** `App.shared` is `static late App shared;` (`App.dart:72`) and is only assigned at line ~211 via `shared = App._(...)`. Any `shared.<field>` read/write before line 211 throws `LateInitializationError` and crashes the app on **every** cold start (the analyzer will NOT catch this — it only surfaces at runtime). So the Drift read must use the **local** `db` (available at line ~140), and the only `shared.` write must be **deferred** to the post-construction block — alongside the existing `shared.meditationPosesApi = ...` at line ~239.
  - **Near line ~140**, right after `final db = Database();`, read the cache into a **local** using the local `db` (no `shared.` access here):
    ```dart
    final cachedPoses = await db.meditationPosesDao.getAll();
    final cachedPoseUuids = cachedPoses.isEmpty
        ? null
        : { for (final p in cachedPoses) p.slug: p.id };
    ```
  - **After construction (~line 239)**, alongside `shared.meditationPosesApi = ...`, publish to the singleton:
    ```dart
    if (cachedPoseUuids != null) shared.meditationPoseUuids = cachedPoseUuids;
    ```
  - **Guard:** only overwrite `meditationPoseUuids` when Drift has rows (`cachedPoseUuids != null`); on first-ever launch the table is empty and the map stays `const {}`.
  - **Style:** keep the post-construction assignment compact and avoid trailing commas, consistent with the in-file initializer style rule in `App.dart`.
  - Do NOT call `refresh()` from `initialize()` — the refresh stays lazy (screen-driven).

- [x] **Task 6: Persist poses to Drift in MeditationListService.refresh()** (depends on Task 4, Task 5)
  Files: `lib/MeditationModule/MeditationListService.dart`
  In `refresh()`, after a successful `listPoses()` fetch and **before** updating `App.shared.meditationPoseUuids`, write to Drift via the generated getter on the shared `db`:
  ```dart
  await App.shared.db.meditationPosesDao.saveAll(
    poses.map((p) => (id: p.id, slug: p.slug, displayOrder: p.displayOrder)).toList(),
  );
  ```
  (`App.shared.db` is safe here — `refresh()` only runs from the screen, long after `initialize()` has assigned `shared`.) Keep the existing `try/catch` with `debugPrint` so a failed fetch/write stays swallowed and does not break the screen.

- [x] **Task 7: Verify analyzer is clean** (depends on Task 6)
  Run `/usr/local/bin/flutter analyze` and resolve any errors introduced by the changes. Note: `flutter analyze` does NOT catch `LateInitializationError` — the Task 5 ordering correctness is the safeguard against the cold-start crash, not the analyzer.

## Commit Plan
- **Commit 1** (after tasks 1-3): "Add MeditationPoses Drift table, DAO, and schema v4 migration"
- **Commit 2** (after tasks 4-7): "Persist and pre-load meditation pose UUIDs from Drift for offline lookup"
