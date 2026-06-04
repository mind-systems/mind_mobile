# Code Review: Persist meditation poses to Drift for offline UUID lookup

**Plan:** `.ai-factory/plans/17-persist-meditation-poses-to-drift-for-offline-uuid-lookup.md`
**Files reviewed (in full):** `lib/Core/Database/MeditationPosesDao.dart` (new), `lib/Core/Database/Database.dart`, `lib/Core/Database/Database.g.dart` (generated), `lib/Core/App.dart`, `lib/MeditationModule/MeditationPosesGrpcApi.dart`, `lib/MeditationModule/MeditationListService.dart`, plus consumer trace through `packages/meditation_module/` + `lib/MeditationModule/` + `lib/router.dart`.

## Summary

The diff under review is **correctly implemented for its stated scope**: the `MeditationPoses` Drift table, DAO, schema-4 migration, generated code, App-init pre-populate, and refresh-time upsert are all sound. The previously-blocking `App.shared`-ordering defect (plan-review C1) is genuinely fixed — the Drift read uses the local `db` (`App.dart:141`) and the only `shared.` write is deferred to post-construction (`App.dart:242`).

However, tracing the runtime path surfaces one **high-severity correctness gap**: the `meditationPoseUuids` cache that this entire milestone exists to populate and persist **is never read anywhere in the codebase**. As written, this milestone does not (and cannot) prevent the UUID crash it targets.

---

## Findings

### 🔴 H1 — `meditationPoseUuids` has no reader; the slug→UUID translation never happens, so the milestone's goal is unmet

`meditationPoseUuids` appears in exactly three places, all **writes**:
- `lib/Core/App.dart:100` — declaration
- `lib/Core/App.dart:242` — pre-populate from Drift (this milestone)
- `lib/MeditationModule/MeditationListService.dart:16` — populate from gRPC fetch

There is **no read site** (`rg meditationPoseUuids '**/*.dart'` → 3 hits, all assignments). The session-start path passes the raw slug straight through to the backend `refId`:

```
MeditationListScreen: onPoseTap(pose.id)          // pose.id = 'easy' | 'lotus' | … (slug)
  → MeditationListViewModel.onPoseTap(id)         // MeditationListViewModel.dart:31
  → MeditationListCoordinator.openSession(poseId) // MeditationListCoordinator.dart:12 — slug
  → router: state.extra as String                 // router.dart:64 — slug
  → MeditationModule.buildSession(poseId: slug)   // MeditationModule.dart:23
  → MeditationModuleStateChannel._onState         // MeditationModuleStateChannel.dart:29
  → _channel.start(refId: _poseId)                // refId = slug, NOT the UUID
```

`pose.id` is a hardcoded slug (`packages/meditation_module/lib/src/Models/MeditationPoses.dart:11-18`). Nowhere between the tap and `_channel.start` is `meditationPoseUuids[slug]` consulted. The backend therefore still receives the slug as `refId` and — per the spec's own problem statement — throws `invalid input syntax for type uuid`.

**Consequence:** every artifact added by this milestone (table, DAO, migration, pre-populate, upsert) is currently **dead code**. Persisting the cache offline is moot while the cache has no consumer; the crash this milestone is meant to fix persists in all scenarios (online and offline).

**Important caveat on ownership:** this gap is *not introduced by this diff* — it is inherited. The consumer was expected from prior commits (`79fdab6` "App.meditationPoseUuids slug→UUID cache", `3e8e522` "Fetch pose UUIDs when meditation list opens"), but the actual lookup at the `refId` call site was never wired. So the diff itself is clean; the milestone's *effectiveness* is what's broken.

**Recommendation:** before closing this milestone, wire the translation at the `refId` boundary, e.g. in `MeditationModuleStateChannel`:
```dart
final refId = App.shared.meditationPoseUuids[_poseId] ?? _poseId;
_channel.start(type: ActivityType.meditation, refId: refId);
```
(or translate once in `MeditationModule.buildSession` / the coordinator). If the consumer is intentionally deferred to a separate roadmap milestone, that should be stated explicitly — otherwise this work ships as unobservable infrastructure and QA step 2 ("start session → no UUID crash") cannot pass.

---

## Verified correct (no action needed)

- **App.shared ordering (C1 from plan review) — fixed.** `App.dart:141-142` reads via the local `db`; `App.dart:242` publishes after `shared = App._(...)` (line 239). No `shared.` access before assignment. No `LateInitializationError`.
- **Migration.** `schemaVersion = 4`; `onUpgrade` adds `if (step == 3) createTable(meditationPoses)` inside the existing `for` loop (`Database.dart:39-41`), firing on the 3→4 hop. Fresh installs use Drift's default `onCreate = createAll()` (no `onCreate` override), which creates the new table too. Both paths covered.
- **Generated code consistent.** `Database.g.dart` exposes `$MeditationPosesTable`, `MeditationPoseRow`, `MeditationPosesCompanion`, `_$MeditationPosesDaoMixin`, and the `db.meditationPosesDao` getter (line 1361). Matches the hand-written DAO.
- **Proto/type mapping.** `meditation_poses.pb.dart` exposes `int get displayOrder` (field 3); the record `({String id, String slug, int displayOrder})` and `IntColumn get displayOrder` align. No type mismatch.
- **Upsert-only guard.** `saveAll` uses `batch(insertAllOnConflictUpdate)` with no delete path — server-removed poses are retained locally, correct for an append-only catalogue.
- **Pre-populate guard.** `cachedPoseUuids` is `null` when Drift is empty, so the `const {}` default is preserved on first launch; the map is only overwritten when rows exist.
- **First-launch-offline limitation** is documented in the plan's Context — expected, not a defect.

## Minor / non-blocking observations

- **`refresh()` fully replaces the in-memory map** (`MeditationListService.dart:16-18`) from the server response, while Drift is upsert-only. If the server ever returns a subset, the in-memory map for that session drops the missing entries even though Drift retains them; the next cold start restores them from Drift. Consistent with the documented append-only intent — noting for awareness only.
- **`batch`/`insertAllOnConflictUpdate` is new to this codebase** (other DAOs use single-row `insertOnConflictUpdate`). Valid Drift API; just a convention divergence.
- **DAO has no interface** (`SyncStateDao`/`BreathSessionDao` implement `ISyncStateDao`/`IBreathSessionDao`). Acceptable given the DAO is reached via the generated `db.meditationPosesDao` getter rather than injected, but it diverges from the local pattern.

---

## Verdict

The code changes are well-formed and the prior blocking defect is resolved, but **H1** means the milestone does not achieve its purpose as merged: the persisted cache is never consumed, so the UUID crash remains. Resolve H1 (wire the slug→UUID lookup at the `refId` site, or explicitly confirm it is a separate follow-up milestone) before considering this done.
