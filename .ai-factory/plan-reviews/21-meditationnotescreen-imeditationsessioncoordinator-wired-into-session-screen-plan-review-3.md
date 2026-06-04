# Plan Review 3: MeditationNoteScreen + IMeditationSessionCoordinator wired into session screen

**Plan:** `.ai-factory/plans/21-meditationnotescreen-imeditationsessioncoordinator-wired-into-session-screen.md`
**Files Reviewed:** 10 (plan + 9 codebase targets/specs)
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** ✅ Aligned. The throw-by-default `meditationSessionCoordinatorProvider` lives in the package alongside the interface (mirroring `meditationSessionViewModelProvider`); the concrete `MeditationSessionCoordinator` stays in `lib/` and is injected via `buildSession()`. No domain leakage into the module, no boundary violation. The note screen is a plain `StatefulWidget` with no ViewModel — appropriate for a pure input/return-value screen.
- **Rules (`.ai-factory/RULES.md`):** ✅ No violation. The coordinator is not a Service, no `App.dart` change is made, and wiring is via constructor injection into `ProviderScope.overrides` — consistent with existing `MeditationListCoordinator`/`MeditationSessionViewModel` wiring.
- **Roadmap (`.ai-factory/ROADMAP.md`):** ✅ Linked. Matches the milestone "`MeditationNoteScreen` + `IMeditationSessionCoordinator` wired into session screen". The plan correctly defers the full `onSessionStopped()` behavior (push note screen + persist) to the later milestone (ROADMAP line 78) while wiring a safe placeholder now.

## Critical Issues

### 1. ✅ RESOLVED — runtime crash on session stop

Reviews 1 and 2 flagged a single blocking defect: Task 5 adds a live, synchronous `ref.read(meditationSessionCoordinatorProvider)` on the `active → idle` transition, while the provider is throw-by-default and was never overridden — so every meditation-session stop would throw `UnimplementedError` on the production-routed screen.

This revision **fixes it** with the new **Task 2b**, which adds to `buildSession()`'s `overrides:` list:
```dart
meditationSessionCoordinatorProvider.overrideWithValue(
  MeditationSessionCoordinator(context),
),
```
backed by the Task 2 placeholder whose `onSessionStopped()` is a safe no-op. The runtime-safety note in the plan header now also explains *why* the override must land this milestone (the synchronous `ref.read` throw escapes before `unawaited` can wrap any future) — matching exactly the mechanism described in review 2. No critical issues remain.

Verified against live code:
- `lib/router.dart:60-66` routes `MeditationSessionScreen.path` → `MeditationModule.buildSession(context, poseId: poseId)` — the screen is in production. ✅
- `buildSession()` currently overrides only `meditationSessionViewModelProvider`; Task 2b adds the coordinator override alongside it, with `context` available as the method's `BuildContext` parameter. ✅
- `MeditationSessionCoordinator(context)` constructor signature matches (`lib/MeditationModule/MeditationSessionCoordinator.dart:9`). ✅
- The sole `active → idle` source is `MeditationSessionViewModel.stop()` (`MeditationSessionViewModel.dart:33`), called by the stop `ControlButton` — so the listener fires exactly once per stop, into a no-op. ✅

## Minor Issues / Notes

- **`MeditationNoteScreen` is dead code this milestone.** Task 4 creates and exports the screen, but nothing pushes it until the later wiring milestone. This is intentional per the roadmap split (package-side scaffolding now, navigation later) and causes no analyzer warning (an unused exported public widget is not flagged). No action needed — just noting it is not user-reachable yet.
- **Task 2 — dead `context` field.** After the `close()` body and `go_router` import are removed, `final BuildContext context;` is unread. Not analyzer-flagged (`unused_field` targets private fields only), `package:flutter/widgets.dart` is still needed for the `BuildContext` type, and the field is referenced by Task 2b's `MeditationSessionCoordinator(context)` constructor call. Stays analyzer-clean. ✅
- **Task 1 — adds `flutter_riverpod` to a previously pure-Dart interface file.** `IMeditationSessionCoordinator.dart` currently has no imports; Task 1 adds the riverpod import and a `Provider` declaration. `flutter_riverpod: ^3.0.0` is a direct dependency of `meditation_module` (`pubspec.yaml:13`), so this is valid. `Provider<IMeditationSessionCoordinator>((_) {...})` and `overrideWithValue` are correct Riverpod 3.0 API. ✅
- **Task 4 — `withValues(alpha:)`** is Flutter 3.27+ API, inherited verbatim from note 64. Low risk; confirm toolchain version during implementation.
- **Verified correct:** old `IMeditationSessionCoordinator.close()` has **no other consumer** anywhere in the codebase (grep confirms only the interface + its single concrete implementor reference it), so the Task 1 signature change breaks nothing else; `ok`/`cancel` keys exist in both `app_en.arb` and `app_ru.arb`; `IMeditationSessionCoordinator.dart` is already exported from the barrel (line 11) so Task 1 needs no barrel edit; `MeditationNoteScreen` export added in Task 4; `MeditationSessionScreen` is a `ConsumerStatefulWidget` so `ref.listen` with `.select` is valid in `build()`; `MeditationSessionStatus` enum is `{ idle, active }` so the `active → idle` guard is well-formed; l10n config (`synthetic-package: false`, output `app_localizations.dart`, re-exported via the `mind_l10n` barrel) and the regen command/working-directory are correct; `AppLocalizations.of(context)!` matches `MeditationListScreen.dart`.

## Positive Notes

- **The critical fix from reviews 1 & 2 was applied correctly and minimally.** The new Task 2b adds the override using the existing placeholder, and the plan's runtime-safety note explains the precise failure mechanism (synchronous `ref.read` throw escaping `unawaited`) so a future reader understands why the placeholder must be wired now rather than deferred.
- The state-note reconciling the stale spec (note 64) against the authoritative roadmap milestone remains excellent — it flags `close()` as dead code and names the roadmap as source of truth.
- Localization is handled ARB-first with key reuse and an explicit, correct regeneration command.
- Architecture-faithful: provider/interface in the package, concrete in `lib/`, no domain leakage.
- Commit split is sensible (contract + strings, then UI + trigger), and task dependencies are explicitly declared.

## Verdict

The plan is well-structured, codebase-accurate, and the single blocking defect carried through reviews 1 and 2 is now resolved by Task 2b (override `meditationSessionCoordinatorProvider` with the placeholder coordinator in `buildSession()`). All file paths, API usage, barrel exports, enum/transition assumptions, and localization steps are verified against the live code. Remaining notes are minor and non-blocking. Ready for implementation.

PLAN_REVIEW_PASS
