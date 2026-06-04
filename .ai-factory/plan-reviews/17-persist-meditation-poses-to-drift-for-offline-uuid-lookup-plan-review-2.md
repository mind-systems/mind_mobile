# Plan Review 2: Persist meditation poses to Drift for offline UUID lookup

**Plan:** `.ai-factory/plans/17-persist-meditation-poses-to-drift-for-offline-uuid-lookup.md`
**Files Reviewed:** plan + `App.dart`, `Database.dart`, `SyncStateDao.dart`, `BreathSessionDao.dart`, `MeditationPosesGrpcApi.dart`, `MeditationListService.dart`, `proto/meditation_poses.proto`, generated `meditation_poses.pb.dart`, plan-review-1
**Risk Level:** 🔴 High — the blocking defect from review 1 (C1) is **still present in the plan text**. Not approvable.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** Plan follows the established `part of 'Database.dart';` DAO convention and the `App` singleton DI pattern. No boundary violations. ✔
- **Rules (App.dart STYLE RULE header):** `initialize()` requires single-line initializers, no trailing commas. The Task 5 pre-populate snippet is a control-flow block (collection-`for`), not a named-parameter initializer call, so it is arguably out of scope — but keep it compact and comma-clean. **WARN (non-blocking).**
- **Roadmap (`.ai-factory/ROADMAP.md`):** Implements the "Persist meditation poses to Drift for offline UUID lookup" milestone. Plan body still does not cite the ROADMAP line (review 1 flagged this; unchanged). **WARN (non-blocking).**

## Critical Issues

### 🔴 C1 — UNRESOLVED from review 1: Task 5 accesses `App.shared` before it is assigned → `LateInitializationError` on every cold start

Review 1 flagged this as the blocking defect. **The plan was not edited** — Task 5 (plan lines 80–89) still reads verbatim:

> "right after `final db = Database();` (line ~140), assign `shared.meditationPosesDao = MeditationPosesDao(db);`"
> then immediately `final cachedPoses = await shared.meditationPosesDao.getAll();` … `shared.meditationPoseUuids = { … }`.

`shared` is `static late App shared;` (`App.dart:72`) and is **only assigned at line 211** via `shared = App._(...)`. Lines 140–210 execute *before* that. Any read or write of `shared.<anything>` in that window throws:

```
LateInitializationError: Field 'shared' has not been initialized.
```

`App.initialize()` runs on startup before `runApp`, so this crashes the app on **every** launch — and `flutter analyze` (Task 7) will not catch it; it only surfaces at runtime. This is verified against the current `App.dart`: the existing precedent the plan still ignores is `meditationPosesApi`, a `late final` field deliberately assigned **after** construction at line 239 (`shared.meditationPosesApi = …`) — precisely because line 239 is past the point where `shared` exists. The only safe window for `shared.<field>` access is **between line 211 and 239**, never at line ~140.

**Required fix** (mirror the `meditationPosesApi` pattern — use locals, publish post-construction):

```dart
// near line 140, after `final db = Database();`
final meditationPosesDao = MeditationPosesDao(db);
final cachedPoses = await meditationPosesDao.getAll();
final cachedPoseUuids = cachedPoses.isEmpty
    ? null
    : { for (final p in cachedPoses) p.slug: p.id };

// … after `shared = App._( … );` (line 211), alongside line 239:
shared.meditationPosesDao = meditationPosesDao;
if (cachedPoseUuids != null) shared.meditationPoseUuids = cachedPoseUuids;
```

The plan must be edited so that **no `shared.` access occurs before line 211.** Until the plan text reflects this, it cannot pass.

## Non-blocking Observations

- **The separate `meditationPosesDao` field on `App` is redundant.** Because the DAO is registered in `@DriftDatabase(daos: [...])` (Task 2), Drift generates a `db.meditationPosesDao` getter — exactly how the existing code reaches `db.userDao`, `db.breathSessionDao`, `db.syncStateDao` (App.dart:156–162). The plan adds a `late final MeditationPosesDao meditationPosesDao;` field *and* a manual assignment, which is the very thing that creates the C1 sequencing trap. Simpler and crash-proof: drop the `App` field entirely and use `App.shared.db.meditationPosesDao` in Task 6, and a local `db.meditationPosesDao` for the pre-populate read in Task 5. This sidesteps C1 by construction. Recommended.
- **`batch(...)` / `insertAllOnConflictUpdate` is a new pattern here.** Existing DAOs use single-row `insertOnConflictUpdate`. Both are valid Drift APIs; just diverges from local convention. A plain loop would also work if consistency is preferred.
- **First-ever-launch-while-offline remains unsolved.** If the first launch has no connectivity, Drift is empty, `refresh()` fails silently, the map stays `{}`, and the slug→UUID fallback still returns the slug → the UUID crash persists for that one session. This is a known mitigation limit (fixed only after the first successful online fetch), not a defect — but it should be stated in the plan's Context so QA isn't surprised. Unchanged since review 1.

## Verified Correct

- **Proto mapping (Task 4).** `display_order` (field 3) exists in `proto/meditation_poses.proto` and the generated `meditation_poses.pb.dart` exposes `displayOrder` (lines 91–93). Extending the record to `({String id, String slug, int displayOrder})` is accurate. No `IMeditationPosesGrpcApi` interface exists — "update the concrete class only" is right.
- **Service accessor (Task 5).** `grpcClient.meditationPosesService` exists (`GrpcClient.dart:43`).
- **Migration ordering (Task 2).** `schemaVersion 3 → 4` with `if (step == 3) { await migrator.createTable(meditationPoses); }` inside the `for (step = from; step < to; step++)` loop matches the existing `step == 1` / `step == 2` style and fires on the 3→4 hop. ✔
- **DAO convention (Task 1).** `part of 'Database.dart';` + reliance on the generated `_$MeditationPosesDaoMixin` matches `SyncStateDao.dart` / `BreathSessionDao.dart`. (Minor: those DAOs implement an interface, e.g. `ISyncStateDao`; the new DAO has none — acceptable, but note the inconsistency.)
- **Upsert-only guard.** No delete path preserves server-removed poses locally — correct for an append-only catalogue.

## Verdict

C1 — a guaranteed startup crash — was identified in review 1 and **remains uncorrected in the plan**. The plan is otherwise well-researched and the surrounding tasks check out against the codebase, but as written Task 5 still crashes the app on every cold start.

Do not implement as-is. Fix the `App.shared` access ordering in Task 5 (ideally by dropping the redundant `App` field and using the auto-generated `db.meditationPosesDao`), then re-review.
