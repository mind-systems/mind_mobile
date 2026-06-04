# Plan Review: Fetch pose UUIDs when meditation list opens

**Plan:** `16-fetch-pose-uuids-when-meditation-list-opens.md`
**Files Reviewed:** 5 (plan, spec note, interface, concrete service, ViewModel + supporting App.dart / GrpcApi / barrel)
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`ARCHITECTURE.md` / module-system):** PASS. The plan respects the module boundary — the new `refresh()` method is declared on the package interface (`IMeditationListService`), and only the concrete `MeditationListService` in `lib/` reaches into `App.shared`. No domain knowledge leaks into `packages/meditation_module`. Consistent with the existing pattern where the concrete service bridges domain → package.
- **Rules (`RULES.md`):** PASS. No DTO/Map-as-payload concerns — `listPoses()` already returns a typed record list. No proto changes. No manual `pubspec.yaml` edits.
- **Roadmap (`ROADMAP.md`):** Linkage is implicit. This is the follow-up to plan 15 (`MeditationPosesGrpcApi` + `App.meditationPoseUuids` cache), which created exactly the `meditationPosesApi` field and `meditationPoseUuids` map this plan populates. WARN (non-blocking): the plan body does not cite a ROADMAP milestone line; consider adding the linkage for traceability.

## Verification of Codebase Assumptions

Every concrete claim in the plan was checked against the source and holds:

- ✅ `App.shared.meditationPosesApi` exists (`lib/Core/App.dart:99`) and is wired in `initialize()` (line 239).
- ✅ `App.shared.meditationPoseUuids` exists as a **mutable** `Map<String, String>` (`lib/Core/App.dart:100`) — direct reassignment in `refresh()` is valid (the field is not `final`/`late final`).
- ✅ `MeditationPosesGrpcApi.listPoses()` returns `Future<List<({String id, String slug})>>` (`lib/MeditationModule/MeditationPosesGrpcApi.dart:9`) — exactly the shape the comprehension `{ for (final p in poses) p.slug: p.id }` consumes.
- ✅ Import path style: `package:mind/Core/App.dart` is the form already used in `lib/MeditationModule/MeditationModule.dart:4`. Task 2's instruction to "match existing style" resolves correctly.
- ✅ `IMeditationListService` and `MeditationListViewModel` are both re-exported from the package barrel (`meditation_module.dart`), so the interface change is visible to the concrete service.
- ✅ `MeditationListViewModel.build()` currently returns `MeditationListState(poses: service.poses())` with no `watch` calls — `build()` runs once, so the fire-and-forget `refresh()` fires once per screen open, as intended.

## Critical Issues

None.

## Minor Issues / Suggestions

1. **Silent catch vs. "Logging: minimal" setting (WARN).** Plan Settings declares `Logging: minimal`, but Task 2 swallows the error with a comment-only `catch` and no log at all. A single `debugPrint`/log line in the `catch` would (a) satisfy the minimal-logging intent and (b) make a silent network failure diagnosable, since the only user-visible symptom is "session silently not recorded server-side." Recommend one log statement in the catch block. Non-blocking.

2. **`unawaited` side effect inside Riverpod `build()` (note, not a defect).** Firing an async side effect from `build()` is acceptable here because the Notifier has no reactive dependencies and rebuilds only on screen construction. If a future change adds a `ref.watch` to `build()`, the refresh would re-fire on every rebuild. Worth a one-line code comment at the call site to flag that the fire-and-forget assumes a single build. Optional.

3. **Catch breadth.** `catch (e)` with `e` unused will trigger an `unused_local_variable`/lint nudge depending on analyzer config. Prefer `on Object catch (_)` or `catch (_)` if no logging is added, or reference `e` in the log if suggestion #1 is taken. Cosmetic.

## Positive Notes

- Correct architectural placement: the boundary is respected, no domain leakage, matches the established service-bridge pattern.
- Task dependencies are accurate (Task 2 and Task 3 both depend only on Task 1, and are independent of each other — they can proceed in parallel after the interface lands).
- The fire-and-forget design genuinely preserves instant rendering of the static pose list; no loading state is introduced, as required.
- Graceful degradation is well-specified: on fetch failure the cache stays empty and the channel falls back to slug, which is the pre-existing safe default.
- Plan is appropriately scoped to a single logical change with a single commit.

The plan is implementable as written; the suggestions above are quality refinements, not blockers.
