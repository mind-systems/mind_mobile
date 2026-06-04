# Plan Review (2): Fetch pose UUIDs when meditation list opens

**Plan:** `16-fetch-pose-uuids-when-meditation-list-opens.md`
**Files Reviewed:** 6 (plan, spec note, interface, concrete service, ViewModel, GrpcApi, supporting App.dart / MeditationModule.dart)
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (module-system):** PASS. The boundary is respected — `refresh()` is declared on the package interface `IMeditationListService`, and only the concrete `MeditationListService` in `lib/` reaches into `App.shared`. No domain knowledge leaks into `packages/meditation_module`. This matches the established service-bridge pattern (concrete service in `lib/`, interface in the package).
- **Rules (`RULES.md`):** PASS. No raw Map-as-payload across the API boundary — `listPoses()` returns a typed record list `List<({String id, String slug})>`. No proto changes. No manual `pubspec.yaml` edits.
- **Roadmap (`ROADMAP.md`):** PASS. The review-1 WARN (missing milestone citation) is now resolved — the plan Context cites ROADMAP line 59 and links the prior milestone (commit `79fdab6`).

## Resolution of Review-1 Findings

All three minor issues from review-1 are addressed in this revision:

1. ✅ **Silent catch / minimal-logging mismatch** — Task 2 now emits `debugPrint('MeditationListService.refresh failed: $e');` in the catch block, satisfying the `Logging: minimal` setting and making a silent network failure diagnosable.
2. ✅ **Fire-and-forget assumption** — Task 3 now embeds an inline comment at the call site flagging that `unawaited(service.refresh())` assumes a single `build()` (no `ref.watch`), and would re-fire on rebuild if a reactive dependency is ever added.
3. ✅ **Unused-variable lint** — referencing `e` in the `debugPrint` removes the `unused_local_variable` concern.

## Verification of Codebase Assumptions

Every concrete claim re-checked against current source and holds:

- ✅ `App.shared.meditationPosesApi` exists (`lib/Core/App.dart:99`, `late final`) and is wired in `initialize()` (`lib/Core/App.dart:239`).
- ✅ `App.shared.meditationPoseUuids` is a **mutable** non-final field (`lib/Core/App.dart:100`, `Map<String, String> ... = const {}`) — direct reassignment in `refresh()` is valid. The existing comment confirms it is intentionally "populated lazily when the meditation list opens, NOT in initialize()" — exactly what this plan implements.
- ✅ `MeditationPosesGrpcApi.listPoses()` returns `Future<List<({String id, String slug})>>` (`lib/MeditationModule/MeditationPosesGrpcApi.dart:9`) — the comprehension `{ for (final p in poses) p.slug: p.id }` consumes this shape correctly.
- ✅ Current `IMeditationListService` declares only `List<MeditationPoseDTO> poses();` (interface file) — adding `Future<void> refresh();` is a clean additive change.
- ✅ Current `MeditationListService` implements only `poses()` — Task 2's `@override Future<void> refresh()` is the only new member; no signature conflict.
- ✅ Current `MeditationListViewModel.build()` is `=> MeditationListState(poses: service.poses())` with no `watch` calls — the refactor to a local variable + `unawaited(service.refresh())` + return is mechanically correct and preserves single-fire semantics.
- ✅ Import path `package:mind/Core/App.dart` matches the form used in `lib/MeditationModule/MeditationModule.dart:4`.
- ✅ `IMeditationListService` and `MeditationListViewModel` are re-exported via the `meditation_module` barrel (the concrete service and the module both already import them through `package:meditation_module/meditation_module.dart`).

## Critical Issues

None.

## Minor Issues / Suggestions

None blocking. Two optional notes:

1. **`debugPrint` import location.** Task 2 correctly adds `package:flutter/foundation.dart` for `debugPrint`. The concrete service currently imports only the package barrel, so this is a genuinely new import — the plan accounts for it. No action needed; just confirming the plan did not assume the import was already present.
2. **`catch (e)` breadth.** A bare `catch (e)` catches everything including `Error` subtypes (not just `Exception`). For a fire-and-forget network call this is the intended graceful-degradation behavior (any failure → keep empty cache → fall back to slug), so it is acceptable here. No change required.

## Positive Notes

- Architectural placement is correct: boundary respected, no domain leakage, matches the established concrete-service-bridge pattern.
- Task dependencies are accurate — Tasks 2 and 3 both depend only on Task 1 and are mutually independent.
- Fire-and-forget design genuinely preserves instant rendering of the static pose list; no loading state introduced.
- Graceful degradation is well-specified and matches the pre-existing safe default (empty cache → slug fallback).
- Scope is tight: a single logical change with a single commit, and the commit message is pre-specified.
- The revision cleanly closed all review-1 findings without introducing new risk.

The plan is implementable as written with no remaining blockers.

PLAN_REVIEW_PASS
