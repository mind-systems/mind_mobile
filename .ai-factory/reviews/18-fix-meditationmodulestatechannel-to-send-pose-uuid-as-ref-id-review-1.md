# Code Review: Fix MeditationModuleStateChannel to send pose UUID as ref_id

**Plan:** `.ai-factory/plans/18-fix-meditationmodulestatechannel-to-send-pose-uuid-as-ref-id.md`
**Scope reviewed:** `git diff HEAD` — two source files (`MeditationModuleStateChannel.dart`, `MeditationModule.dart`) plus plan/metadata artifacts.

## What changed

1. **`lib/MeditationModule/Core/MeditationModuleStateChannel.dart`** — constructor param `poseId → refId`, field `_poseId → _refId`. The internal `App.shared.meditationPoseUuids[...]` lookup in `_onState` was removed; `_channel.start()` now passes `_refId` directly. The now-dead `package:mind/Core/App.dart` import was removed.
2. **`lib/MeditationModule/MeditationModule.dart`** — `buildSession()` now resolves `final refId = App.shared.meditationPoseUuids[poseId] ?? poseId;` and passes `refId:` to the channel. `MeditationSessionViewModel(poseId: poseId)` is unchanged (slug still drives image/title).

## Correctness verification

- **Field/param rename is complete and consistent** — `_refId` is declared (line 9), initialized (line 20), and the only read site (line 29) all use the new name. No stale `poseId`/`_poseId` references remain in the file.
- **Import hygiene** — `App` was referenced only at the removed lookup; the dropped import is correct. The file still compiles against its remaining imports (`ActivityType`, `ModuleStateChannel`, `meditation_module`). In `MeditationModule.dart` the `App` import is retained and still used (lines 25, 31). Correct.
- **`start()` signature match** — `refId` is `String`; `ModuleStateChannel.start({required ActivityType type, String? refId})` accepts it. No type mismatch.
- **Single call site** — `MeditationModuleStateChannel(` is constructed only in `buildSession`; the rename has no other callers. No tests reference it.
- **Fallback preserved** — `?? poseId` retains the documented slug fallback when the cache is empty (server-reject behavior, no new crash mode).

## Timing-shift analysis (the only behavioral change)

UUID resolution moved from lazy (`_onState`, at session-*active*) to eager (`buildSession`, at screen-build). Verified this is safe:

- The cache is populated from Drift at cold start (`App.dart:142,242`, `cachedPoseUuids`) and refreshed when the meditation list opens (`MeditationListService.dart:16`).
- `buildSession` only runs after navigating *from* the list screen, by which point the cache is already populated via either path. The narrow window where the cache could fill *between* build and active-status no longer benefits resolution — but in the real flow the map is already filled before `buildSession`, so resolution is equivalent. The slug fallback covers the offline/empty case identically to before.

No race, null-safety, or lifecycle regression introduced. `dispose()` / re-arm logic is untouched and still correct.

## Findings

None. The implementation matches the plan exactly, is minimal, type-safe, and behavior-preserving aside from the intended fix.

REVIEW_PASS
