# Plan Review 3: Persist meditation poses to Drift for offline UUID lookup

**Plan:** `17-persist-meditation-poses-to-drift-for-offline-uuid-lookup.md`
**Risk Level:** 🟢 Low

## Verification Against Codebase

Every load-bearing claim in the plan was checked against the actual source. All correct:

| Plan claim | Verified |
|---|---|
| `SyncStateDao.dart` / `BreathSessionDao.dart` use `part of 'Database.dart';` with no top-level imports | ✅ `SyncStateDao.dart:1` confirms `part of 'Database.dart';` |
| Existing DAOs use single-row `insertOnConflictUpdate` (not `batch`) | ✅ `SyncStateDao.dart:35` |
| `Database.dart` schema version is 3, registers `[UserRecord, BreathSessions, SyncState]` | ✅ `Database.dart:21,26` |
| `onUpgrade` uses a `for` loop with `if (step == N)` style | ✅ `Database.dart:31-38` (`step == 1`, `step == 2`) — so `if (step == 3)` is the correct next entry |
| Generated `db.<dao>` getters exist for registered DAOs | ✅ `db.userDao` (App.dart:156), `db.breathSessionDao` (157), `db.syncStateDao` (162,206) |
| `MeditationPosesGrpcApi.listPoses()` returns `List<({String id, String slug})>`, no interface | ✅ `MeditationPosesGrpcApi.dart:9-12` — concrete class only, no `IMeditationPosesGrpcApi` |
| proto `display_order` is field 3; generated getter is `displayOrder` | ✅ `meditation_poses.proto:17`; `meditation_poses.pb.dart:91` exposes `displayOrder` getter |
| `MeditationListService.refresh()` is wrapped in `try/catch` + `debugPrint` | ✅ `MeditationListService.dart:10-19` |
| `App.shared` is `static late App shared;` (line 72), assigned at ~211 | ✅ `App.dart:72`, `shared = App._(...)` at `App.dart:211` |
| `meditationPoseUuids` declared `= const {}` (line ~100), set lazily | ✅ `App.dart:100` |
| `shared.meditationPosesApi = ...` deferred post-construction at ~239 | ✅ `App.dart:239` |
| `final db = Database();` at ~140 | ✅ `App.dart:140` |
| `grpcClient.meditationPosesService` exists | ✅ used at `App.dart:239` already |

## Context Gates

- **Architecture:** The plan respects the layered architecture — domain DAO in `lib/Core/Database/`, no module/package boundary violations, generated-getter access pattern consistent with existing DAOs. **PASS**
- **Rules / Style:** The plan explicitly honors the in-file `App.dart` style rule (single-line initializers, no trailing commas) — matches the header comment at `App.dart:1-4` and the user's memory note `feedback_app_dart_style.md`. **PASS**
- **Roadmap:** Plan is anchored to ROADMAP line 61 / Phase 33. **PASS**

## Strengths (improvements over the spec note)

1. **Correctly rejects the spec note's `shared.meditationPosesDao` field approach.** The note (`101-...md` steps 3-4) would have written `shared.meditationPosesDao = ...` near line 140 — *before* `shared` is assigned at 211 — triggering `LateInitializationError` on every cold start. The plan catches this (Task 5) and routes through the generated `db.meditationPosesDao` getter on the local `db` instead. This is the single most important correction and it is correct.
2. **Read uses local `db`, write to `shared.meditationPoseUuids` is deferred** to the post-construction block. The `cachedPoseUuids` local is in scope from ~140 to ~239 within `initialize()`. Sound.
3. **Empty-table guard** (`cachedPoseUuids != null`) preserves `const {}` on first launch — correct, and the scope caveat (first-ever offline launch still crashes) is honestly disclosed for QA.
4. **`part of` convention** correctly chosen over the standalone-import style the spec note implied.
5. **Migration** correctly placed in the `for`/`if (step == 3)` loop rather than the note's `if (from < 4)` form.

## Minor Notes (non-blocking)

1. **Task 1 `batch`/`insertAllOnConflictUpdate` is new to this codebase.** The plan already flags this and offers a plain-loop fallback. Both are valid Drift APIs; no action required, just be aware the generated `_$MeditationPosesDaoMixin` and `MeditationPosesCompanion` must exist post-`build_runner` (Task 3) before Task 1's code analyzes clean. The Task ordering (1 → 2 → 3) means Task 1's file will reference not-yet-generated symbols until Task 3 runs — expected for Drift `part` files; analyzer will only be clean after Task 3, which Task 7 covers.
2. **`getAll()` ordering is unused by the cache map** (insertion order into a `Map` doesn't affect `meditationPoseUuids` lookups). The `orderBy displayOrder` is harmless and forward-looking if the table is ever read for display. No change needed.
3. **`saveAll` upsert-only / no-delete** is intentional and documented. Server-side pose removals will linger locally until... never (no full-replace). Acceptable per the note's "append-only in practice" assumption; worth a one-line comment in code so a future reader doesn't mistake it for a bug.

None of these block implementation.

## Conclusion

The plan is internally consistent, every file path and API reference checks out against the current source, the schema migration is correct, and the critical cold-start ordering hazard is both understood and correctly mitigated. No missing steps, no wrong assumptions, no missing migration, no security concerns (local catalogue data only, no injection surface — Drift companions are parameterized).

PLAN_REVIEW_PASS
