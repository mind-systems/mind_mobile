## Plan Review: Drift `meditation_notes` table + `MeditationNoteRepository`

**Plan:** `22-drift-meditation-notes-table-meditationnoterepository.md`
**Files Targeted:** 5 (2 new, 3 modified incl. generated)
**Risk Level:** 🟢 Low

### Context Gates

- **Architecture (`ARCHITECTURE.md`)** — ✅ Aligned. DI wiring order is `Database → Repositories → Notifiers`. The plan inserts `MeditationNoteRepository` after the DB is constructed, consistent with `breathSessionRepository`/`userRepository`. The Drift split-file (`part of`) pattern matches the documented Core/Database structure.
- **Rules (`RULES.md`)** — ⚠️ WARN (non-blocking). RULES line 8: *"Never add module-specific state, streams, or triggers to App.dart — App.dart is infrastructure only (DB, HTTP, notifiers, sync)."* The plan adds `meditationNoteRepository` to `App`. This is acceptable and consistent with existing precedent: `breathSessionRepository` and `userRepository` are DB-access repositories already living in `App.dart`. A repository is infrastructure (DB access), not "state/streams/triggers." No action required, but flagging for awareness — the *Service*/*coordinator* (later milestones 77/79) must not leak module state into `App`.
- **Roadmap (`ROADMAP.md`)** — ✅ Aligned. Plan maps cleanly to the milestone at line 75 ("Drift `meditation_notes` table + `MeditationNoteRepository`"). Column contract, no-FK/no-cascade rule, and `uuid` guard all match. Correctly defers Service/coordinator/gRPC to milestones 77 & 79.

### Verified Against Codebase

- **`Database.dart`** — confirmed `schemaVersion => 4`, the `for (var step = from; step < to; step++)` stepwise `onUpgrade`, and the `@DriftDatabase(tables: [...], daos: [...])` list. The plan's `if (step == 4) { createTable(meditationNotes); }` is the correct next step. No `onCreate` override exists, so Drift's default `createAll()` covers fresh installs — plan's note is accurate.
- **`MeditationPosesDao.dart`** — confirmed as a faithful template: `@DataClassName`, `TextColumn get id`, `primaryKey => {id}`, `@DriftAccessor`, `_$...DaoMixin`, `MeditationPosesDao(super.db)`. Plan mirrors this exactly.
- **`App.dart`** — confirmed `late final MeditationPosesGrpcApi meditationPosesApi;` post-construction field assigned *after* `shared = App._(...)` (line 241), NOT in the `App._` required constructor. Plan correctly follows this pattern and respects the documented single-line / no-trailing-comma style rule (lines 1–3).
- **`db.meditationNotesDao`** — accessor will be generated once the DAO is registered; usage in Task 5 is correct.
- **`uuid: ^4.5.3`** — confirmed in `pubspec.yaml`. `const Uuid().v4()` is the established idiom (used in `User.dart`, `DeviceRepository.dart`, `BreathSessionConstructorService.dart`). Plan's usage matches.
- **Spec note 88** — `poseId` stores the pose UUID (not slug), no FK, no cascade. Plan's column contract and `save(String poseId, ...)` signature match exactly.
- **`lib/MeditationModule/`** — directory exists; new repository path is valid.

### Correctness Notes

- **Companion usage is correct.** `MeditationNotesCompanion.insert(...)` requires non-nullable columns (`id`, `poseId`, `noteText`, `createdAt`) as raw values and the nullable `serverSessionId` as `Value(...)` — exactly what the plan writes. Generated names (`MeditationNoteRow`, `MeditationNotesCompanion`) follow from `@DataClassName('MeditationNoteRow')` + table class `MeditationNotes`.
- **`createdAt` type** — `DateTime.now().millisecondsSinceEpoch` is an `int`, matching `IntColumn`. ✅
- **No missing migration.** Schema bump 4→5 + `createTable` step is the only DB change required; correctly captured.

### Minor / Optional Observations (non-blocking)

- Task 4 describes the repository as "pure-Dart (no Flutter/Riverpod imports)." It transitively imports `Database.dart`, which pulls in `drift_flutter`/`path_provider`. This is identical to `BreathSessionRepository`'s situation and fully consistent with the codebase's notion of "pure domain logic, no UI" — no change needed, just noting the wording.
- Commit messages in the plan use imperative-style phrases without type prefixes, consistent with the repo's commit conventions. ✅

### Positive Notes

- Strong grounding: every claim about `schemaVersion`, the migration loop, the post-construction `late final` field pattern, and the DAO template is verifiable and correct.
- Correctly resolves the milestone's loose naming (`AppDatabase` → `Database`, `MeditationNotesTable` → `MeditationNotes`) against actual codebase conventions and documents the reasoning.
- Properly scoped: persistence only, with Service/gRPC explicitly deferred to downstream milestones — no scope creep, no premature wiring that would violate the App.dart infrastructure rule.
- Dependency graph between tasks (1→2→3→4→5) is accurate and the build_runner regeneration step is not forgotten.

PLAN_REVIEW_PASS
