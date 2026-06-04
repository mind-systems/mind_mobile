# Code Review 2: Persist meditation poses to Drift for offline UUID lookup

**Plan:** `.ai-factory/plans/17-persist-meditation-poses-to-drift-for-offline-uuid-lookup.md`
**Files reviewed (in full):** `lib/Core/Database/MeditationPosesDao.dart`, `lib/Core/Database/Database.dart`, `lib/Core/Database/Database.g.dart` (generated), `lib/Core/App.dart`, `lib/MeditationModule/MeditationPosesGrpcApi.dart`, `lib/MeditationModule/MeditationListService.dart`, `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`, plus consumer trace through `packages/meditation_module/` and `lib/router.dart`.

## Summary

All findings from review 1 are resolved, and re-tracing the runtime path turns up no new defects.

### H1 (review 1) — RESOLVED: the slug→UUID cache now has a consumer

Review 1's blocking finding was that `meditationPoseUuids` was written but never read, so the slug was sent to the backend as `refId` and the UUID crash persisted. This is now fixed at the correct boundary — `MeditationModuleStateChannel._onState` (`MeditationModuleStateChannel.dart:30-31`):

```dart
final refId = App.shared.meditationPoseUuids[_poseId] ?? _poseId;
_channel.start(type: ActivityType.meditation, refId: refId);
```

This is the right place: the lookup runs lazily at session-start (`active` status), by which point the map is populated either by the cold-start Drift pre-populate (`App.dart:242`) or the list screen's `refresh()` (`MeditationListService.dart:16`). `_poseId` is the slug (`'easy'`, `'lotus'`, … from `kMeditationPoses`), the map is slug→UUID, and the `?? _poseId` fallback preserves the documented first-launch-offline edge case rather than introducing a null/throw. `App.shared` is fully assigned long before any session starts, so there is no `LateInitializationError` risk here.

### C1 (plan review) — confirmed still resolved

`App.dart:141-142` reads from the **local** `db` and builds `cachedPoseUuids`; the only `shared.` write is deferred to `App.dart:242`, after `shared = App._(...)` (line 239). No `shared.` access before assignment.

## Verified correct (unchanged since review 1)

- **Migration.** `schemaVersion = 4`; `onUpgrade` adds `if (step == 3) createTable(meditationPoses)` inside the existing `for` loop (`Database.dart:39-41`). Fresh installs fall through to Drift's default `onCreate = createAll()` (no override), creating the table. Both paths covered.
- **Generated code consistency.** `Database.g.dart` exposes `$MeditationPosesTable`, `MeditationPoseRow`, `MeditationPosesCompanion`, `_$MeditationPosesDaoMixin`, and the `db.meditationPosesDao` getter (line 1361) — matches the hand-written DAO.
- **Type mapping.** Proto `meditation_poses.pb.dart` exposes `int get displayOrder` (field 3); the record `({String id, String slug, int displayOrder})`, `IntColumn get displayOrder`, and the `saveAll` companion mapping all align. No type mismatch.
- **Upsert-only guard.** `saveAll` uses `batch(insertAllOnConflictUpdate)` with no delete path — server-removed poses are retained locally (append-only catalogue).
- **Pre-populate guard.** `cachedPoseUuids` is `null` when Drift is empty, so the `const {}` default is preserved on first launch; the map is overwritten only when rows exist.
- **`refresh()` error handling.** Drift write occurs before the in-memory map update, both inside the existing `try/catch` with `debugPrint`; a failed fetch/write is swallowed and does not break the screen.

## Non-blocking observations (informational, not defects)

- **`App.shared` is reached as a service locator inside `MeditationModuleStateChannel`** rather than injected via constructor (RULES.md: "dependencies injected via constructor"). This mirrors the existing pattern in `MeditationModule.dart` (`App.shared.moduleStateChannel`), and `meditationPoseUuids` is intentionally a shared-mutable global per the milestone spec (plan-review-1 explicitly noted this is by design, not a defect). The lazy lookup at `active` status is also more robust than resolving at `buildSession` time, since the map may still be populating. Acceptable as-is.
- **Tap-before-refresh race on first-ever offline launch** still leaves the map empty → `?? _poseId` sends the slug → backend rejects the UUID. This is the documented, out-of-scope first-launch-offline limitation (plan Context), not a regression.

## Verdict

The blocking gap from review 1 is fixed with the lookup wired at the correct boundary; the migration, generated code, type mapping, guards, and ordering are all sound. No outstanding defects.

REVIEW_PASS
