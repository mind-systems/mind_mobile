# Plan Review: Persist meditation poses to Drift for offline UUID lookup

**Plan:** `.ai-factory/plans/17-persist-meditation-poses-to-drift-for-offline-uuid-lookup.md`
**Files Reviewed:** 5 (plan + App.dart, Database.dart, SyncStateDao.dart, MeditationPosesGrpcApi.dart, MeditationListService.dart, meditation_poses.proto, note 101)
**Risk Level:** 🔴 High — one critical runtime-crash defect blocks approval

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** Present. Plan adds a Drift table + DAO via the established `part of 'Database.dart';` convention and a `late final` DAO field on the `App` singleton — consistent with existing DI wiring. No boundary violations. ✔
- **Rules (`.ai-factory/RULES.md` + App.dart STYLE RULE header):** `lib/Core/App.dart` carries an explicit in-file style rule: *"All initializers in initialize() must be written as single-line statements … No trailing commas."* The Task 5 pre-populate snippet uses a multi-line collection-`for` map literal inside `initialize()`. This is a control-flow block, not a named-parameter initializer call, so it is arguably out of scope of the rule — but keep the assignment compact and avoid trailing commas to stay safe. **WARN (non-blocking).**
- **Roadmap (`.ai-factory/ROADMAP.md`):** This plan implements **ROADMAP line 61** ("Persist meditation poses to Drift for offline UUID lookup", Phase 33). The plan body does not cite that milestone line. Prior plan reviews (15, 16) flagged the same omission. **WARN (non-blocking):** add the linkage for traceability.

## Critical Issues

### 🔴 C1 — Task 5 accesses `App.shared` before it is assigned → `LateInitializationError` on every cold start

This is the blocking defect. Task 5 instructs:

> "right after `final db = Database();` (line ~140), assign `shared.meditationPosesDao = MeditationPosesDao(db);`" and then immediately `final cachedPoses = await shared.meditationPosesDao.getAll();` … `shared.meditationPoseUuids = { … }`.

But `shared` is `static late App shared;` (`App.dart:72`) and is **only assigned at line 211** via `shared = App._(...)`. Lines 140–210 run *before* that. Any read/write of `shared.<anything>` in that window throws:

```
LateInitializationError: Field 'shared' has not been initialized.
```

`App.initialize()` runs on startup before `runApp`, so this crashes the app on **every** launch — a hard regression, not an edge case. The analyzer will **not** catch it (Task 7's `flutter analyze` passes); it only surfaces at runtime.

Note the existing precedent the plan overlooked: `meditationPosesApi` is a `late final` field that is deliberately assigned **after** construction, at line 239 (`shared.meditationPosesApi = …`), *because* that is the first point where `shared` exists. The plan even references "before `meditationPosesApi` is assigned (~line 239)" as the deadline — but the only safe window for `shared.<field>` access is *between* line 211 and 239, not at line 140.

The root cause is inherited verbatim from the spec note (`notes/101-…md` steps 3–4), which contains the same ordering mistake.

**Required fix** — use locals for the DAO and the cached map, then publish to `shared` after construction (mirror the `meditationPosesApi` pattern):

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

(Or: keep the `getAll()` read where the DAO is created, but defer *both* `shared.` assignments to the post-construction block at ~239.) Either way, no `shared.` access may occur before line 211. The plan must be corrected before implementation, and the same correction should be reflected in note 101 so a future re-run does not reintroduce the bug.

## Non-blocking Observations

- **First-ever-launch-while-offline remains unsolved.** If the very first launch has no connectivity, Drift is empty, `refresh()` fails silently, the map stays `{}`, and `meditationPoseUuids[slug] ?? slug` still returns the slug → the UUID crash persists for that one session. Note 101 (data-flow section) acknowledges this as unavoidable without seeding; the plan body does not mention it. Not a defect — but state it explicitly in the plan's Context so reviewers/QA know the offline crash is only mitigated *after the first successful online fetch*, not eliminated.
- **`batch(...)` is a new pattern in this codebase.** Existing DAOs use single-row `insertOnConflictUpdate` (`UserDao`, `SyncStateDao`, `BreathSessionDao`); none use `batch`/`insertAllOnConflictUpdate`. Both are valid Drift APIs on `DatabaseAccessor`, so this is fine — just noting it diverges from the local convention. A simple loop of `insertOnConflictUpdate` would also work if you prefer consistency.
- **Migration ordering is correct.** `schemaVersion 3 → 4` with `if (step == 3) { await migrator.createTable(meditationPoses); }` inside the `for (step = from; step < to; step++)` loop matches the existing `step == 1` / `step == 2` style and fires for the 3→4 hop. ✔

## Positive Notes

- **Correct read of the DAO convention.** Task 1's explicit instruction to use `part of 'Database.dart';` (not the standalone-import style in the note) and rely on the generated `_$MeditationPosesDaoMixin` exactly matches `SyncStateDao.dart` / `BreathSessionDao.dart`. Good catch overriding the spec.
- **Proto mapping verified.** `display_order` exists in `proto/meditation_poses.proto` (field 3) and maps to the generated `displayOrder` getter; Task 4's record extension to `({String id, String slug, int displayOrder})` is accurate. Confirmed there is no `IMeditationPosesGrpcApi` interface, so "update the concrete class only" is right.
- **Upsert-only guard is sound.** `insertAllOnConflictUpdate` with no delete path preserves server-removed poses locally — correct for an append-only catalogue and avoids wiping the offline cache on a partial fetch.
- **Lazy-refresh boundary respected.** Not calling `refresh()` from `initialize()` (gRPC not yet connected) and keeping the pre-populate Drift-only is the right separation.
- **Commit plan is coherent** — schema/DAO landing first, then wiring, each independently buildable.

## Verdict

The plan is well-researched and almost entirely correct, but **C1 is a guaranteed startup crash** as written. Fix the `App.shared` access ordering in Task 5 (and ideally note 101) before implementing. Address the ROADMAP linkage and first-launch-offline caveat while editing.

Do not implement as-is.
