# Plan Review: Rename local data layer `MeditationNotes` → `ModuleSessionNotes`, drop `poseId`

**Plan:** `12-rename-local-data-layer-meditationnotes-modulesessionnotes-drop-poseid-column.md`
**Files Reviewed:** 7 (plan + 6 target source files) + spec note 11 + roadmap/architecture/rules
**Risk Level:** 🟢 Low

## Verification Performed

Every file path, line number, class name, and method signature in the plan was checked against the live codebase:

- `MeditationNotesDao.dart` — table `MeditationNotes` (`@DataClassName('MeditationNoteRow')`), columns `id`/`poseId`/`noteText`/`createdAt`/`serverSessionId`, PK `{id}`, DAO `MeditationNotesDao` with mixin `_$MeditationNotesDaoMixin`, `insertNote(MeditationNotesCompanion) => into(meditationNotes).insert(...)`. **All match the plan.**
- `Database.dart` — `part 'MeditationNotesDao.dart'`, `@DriftDatabase(tables: [...MeditationNotes], daos: [...MeditationNotesDao])`, `schemaVersion => 5`, migration steps 1–4 with `step == 4` calling `createTable(meditationNotes)`. **All match.**
- `MeditationNoteRepository.dart` — `save(String poseId, String text, {String? serverSessionId})`, `MeditationNotesCompanion.insert(id, poseId, noteText, createdAt, serverSessionId)`. **Matches.**
- `MeditationNoteService.dart` — `_poseSlug` field + `MeditationNoteService(String poseSlug, MeditationNoteRepository)` ctor, `_syncToServer(sessionId, poseId, noteText)` calling `meditationNotesGrpcApi.createNote(...)` with `GrpcError`/`alreadyExists` swallow. **Matches.**
- `App.dart` — import line 60, field line 115, init line 273 all as the plan states; the `MeditationNotesGrpcApi` import (59), field (114), init (272) correctly left untouched. **Line numbers exact.**
- `MeditationModule.dart` — import line 9, construction at line 54. **Exact.**
- `MeditationSessionCoordinator.dart` — import + `IMeditationNoteService noteService` field. **Matches.**

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** PASS. Repository stays in the domain folder (`lib/MeditationModule/`), DAO in `Core/Database/`, Service implements the module-boundary interface. The rename preserves all layer boundaries.
- **Rules (`RULES.md`):** PASS. The Service remains stateless (no streams/dispose), all deps stay constructor-injected, and no new module state is added to `App.dart` — only an existing infra field is renamed.
- **Roadmap (`ROADMAP.md`):** PASS. This is the first task of Phase 60 ("Module session notes migration") and matches the roadmap item verbatim, including the deferral of the gRPC adapter rename to note 12.

## Critical Issues

None.

## Correctness Notes (verified, non-blocking)

1. **Migration step 4/step 5 double-create is safe — confirmed.** The plan's biggest risk was that for a user upgrading from schema v4 (or earlier), the loop runs `step == 4` (`createTable(moduleSessionNotes)`) *and then* `step == 5` (`createTable(moduleSessionNotes)` again), which looks like a "table already exists" crash. I verified drift 2.28.2's `Migrator.createTable` emits `CREATE TABLE IF NOT EXISTS` (`drift/lib/src/runtime/query_builder/migration.dart:309`), so the second create is a harmless no-op. All upgrade paths are sound:
   - Fresh v6 install → default `onCreate`/`createAll` builds `module_session_notes` from the `@DriftDatabase` table list.
   - v5→v6 → step 5 drops `meditation_notes`, creates `module_session_notes`.
   - v4-or-earlier→v6 → step 4 creates `module_session_notes`, step 5's `DROP TABLE IF EXISTS meditation_notes` is a no-op and the re-create is a no-op.
   The plan's instruction to change `step == 4` from `createTable(meditationNotes)` to `createTable(moduleSessionNotes)` is necessary (the old class is being deleted, so it would otherwise fail to compile) and correct.

2. **No test breakage.** The only `poseId` references under `test/` are on `MeditationSessionState` (the session-screen pose, an unrelated `meditation_module` package DTO), not on the note layer. No test imports `MeditationNoteService`/`Repository`/`IMeditationNoteService`/`MeditationNotesDao`, so the `Testing: no` setting is justified — the rename won't break the existing suite.

3. **`meditationPoseUuids` map correctly retained.** Dropping `_poseSlug` from the service removes one consumer of `App.shared.meditationPoseUuids`, but the map is still read in `MeditationModule.buildSession` (`refId = App.shared.meditationPoseUuids[poseId] ?? poseId`, line 32). The plan does not remove the map — correct.

4. **gRPC bridge is sound.** Keeping `_syncToServer` on `App.shared.meditationNotesGrpcApi.createNote(... poseId: '', ...)` compiles against the still-unrenamed adapter; `pose_id` is a proto3 string defaulting to empty, ignored server-side. Cleanly deferred to note 12.

## Minor Observations (informational)

- **Intentional data loss:** `DROP TABLE IF EXISTS meditation_notes` discards any locally-stored meditation notes on existing v5 installs. Spec note 11 (line 10) explicitly confirms "existing data is intentionally not migrated," so this is by design, not an oversight. Flagging only for visibility.
- **Task 2 prose is slightly repetitive** (it explains the step-4 change twice), but the actual instruction is unambiguous and correct. No action needed.

## Positive Notes

- Excellent line-level precision — every cited line number matches the current source exactly.
- The plan proactively caught the step-4 compile hazard (old table class deletion) and addressed it, rather than leaving it as a latent build break.
- Correct separation of concerns: the gRPC adapter rename, proto swap, and `poseId: ''` bridge removal are all cleanly deferred to note 12, keeping this task shippable independently.
- Commit plan is well-staged (Drift table → domain → wiring+codegen), each commit leaving the tree compilable.
- Codegen step correctly mandates `build_runner` regeneration and forbids hand-editing `Database.g.dart`.

PLAN_REVIEW_PASS
