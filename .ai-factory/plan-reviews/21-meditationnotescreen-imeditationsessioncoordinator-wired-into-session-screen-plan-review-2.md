# Plan Review 2: MeditationNoteScreen + IMeditationSessionCoordinator wired into session screen

**Plan:** `.ai-factory/plans/21-meditationnotescreen-imeditationsessioncoordinator-wired-into-session-screen.md`
**Files Reviewed:** 9 (plan + 8 codebase targets/specs)
**Risk Level:** 🔴 High

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** ✅ Aligned. The throw-by-default `meditationSessionCoordinatorProvider` lives in the package alongside the interface (mirroring `meditationSessionViewModelProvider`); the concrete coordinator stays in `lib/`. No domain leakage into the module, no boundary violation.
- **Rules (`.ai-factory/RULES.md`):** ✅ Present now (it was absent at review-1). The three rules concern stateless Services, keeping module state out of `App.dart`, and constructor injection. None is violated by this plan — the coordinator is not a Service, no `App.dart` change is made, and no out-of-band wiring is introduced. WARN downgraded to PASS.
- **Roadmap (`.ai-factory/ROADMAP.md`):** ✅ Linked. Matches the milestone "`MeditationNoteScreen` + `IMeditationSessionCoordinator` wired into session screen" (ROADMAP line 75). The plan correctly defers the concrete coordinator + `buildSession()` override to the later "Concrete `MeditationNoteService` + `MeditationSessionCoordinator` + full wire" milestone. The state-note's "ROADMAP line 77" is approximate but points at the right later milestone.

## Critical Issues

### 1. 🔴 UNRESOLVED FROM REVIEW 1 — stopping a meditation session throws `UnimplementedError` at runtime

This is the same defect raised in review-1, and the plan has **not** been changed to fix it. It still ships a user-facing regression in this milestone.

The contradiction is unchanged:

- **Task 5** adds, inside `MeditationSessionScreen.build()`, a *live* read on every `active → idle` transition:
  ```dart
  unawaited(ref.read(meditationSessionCoordinatorProvider).onSessionStopped());
  ```
- **Task 1** defines `meditationSessionCoordinatorProvider` as **throw-by-default** (`throw UnimplementedError('must be overridden via ProviderScope')`).
- **Task 2** still explicitly forbids the override: *"Do NOT wire this coordinator into `MeditationModule.buildSession()` — that is out of scope for this milestone."*

Verified against the live code:

- `lib/router.dart:61-65` routes `MeditationSessionScreen.path` → `MeditationModule.buildSession(context, poseId: poseId)`. The screen is **in production today**.
- `lib/MeditationModule/MeditationModule.dart` `buildSession()` overrides **only** `meditationSessionViewModelProvider` — it never overrides `meditationSessionCoordinatorProvider`.
- The sole `active → idle` transition source is `MeditationSessionViewModel.stop()` (`MeditationSessionViewModel.dart`), which the stop `ControlButton` calls.

Consequence: user taps stop → `vm.stop()` sets status `idle` → the new listener fires → `ref.read(meditationSessionCoordinatorProvider)` re-throws the cached `UnimplementedError`. Note the `unawaited()` wrapper does **not** protect against this: the `ref.read(...)` is evaluated *synchronously* inside the listener callback, so the throw happens before any `Future` exists for `unawaited` to swallow. The exception escapes as an uncaught error in the provider-listener callback. The asymmetry with `meditationSessionViewModelProvider` (always overridden) is exactly the bug: this milestone adds a live consumer of a provider it deliberately never overrides.

**This must be resolved before implementation.** Fix options (unchanged from review-1):

- **(a) Recommended — override now with the Task 2 placeholder.** In `buildSession()`, add
  ```dart
  meditationSessionCoordinatorProvider.overrideWithValue(
    MeditationSessionCoordinator(context),
  ),
  ```
  using the placeholder whose `onSessionStopped()` is a safe no-op. Zero behavioral cost; the listener becomes a harmless no-op until the real implementation lands. (`meditation_module` and the concrete coordinator import are already available in `MeditationModule.dart`.) This directly contradicts Task 2's "do not wire" instruction — which is the instruction that *creates* the crash — so Task 2 must be amended.
- **(b)** Make the default provider return a no-op coordinator instead of throwing. Diverges from the `meditationSessionViewModelProvider` throw-by-default convention.
- **(c)** Defer Task 5 (the `ref.listen`) to the later wiring milestone so the live consumer and its override land together. Cleanest, but leaves this milestone with only dead package code.

The plan author appears to have read review-1 (the state-note and structure are intact) but did not act on its single critical finding. Whichever option is chosen, the plan text must stop instructing both "add a live consumer of the provider" and "do not override the provider."

## Minor Issues / Notes

- **Task 2 — dead `context` field.** After the `close()` body and `go_router` import are removed, `final BuildContext context;` becomes unused. Not analyzer-flagged (`unused_field` targets private fields only) and `package:flutter/widgets.dart` is still needed for the `BuildContext` type, so the file stays analyzer-clean. If fix option (a) is taken the field stays referenced by the constructor call in `buildSession()`. No action required.
- **Task 4 — `withValues(alpha:)`** is Flutter 3.27+ API, inherited verbatim from note 64. Low risk; confirm toolchain version during implementation.
- **Task 3 — l10n regeneration.** `synthetic-package: false`, `output-localization-file: app_localizations.dart`, and the `mind_l10n` barrel re-export (`export 'l10n/app_localizations.dart';`) are all confirmed. The regen command and working directory are correct.
- **Verified correct:** `ok`/`cancel` keys exist in both `app_en.arb` and `app_ru.arb`; `IMeditationSessionCoordinator.dart` is already exported from the barrel (line 11) so Task 1 needs no barrel edit; `MeditationNoteScreen` export is added in Task 4; `flutter_riverpod ^3.0.0` and `mind_l10n` are dependencies of the package; `AppLocalizations.of(context)!` matches `MeditationListScreen.dart`; `ref.listen` with `.select` is valid inside `ConsumerStatefulWidget.build()`; `Provider<IMeditationSessionCoordinator>((_) {...})` is valid Riverpod 3.0.

## Positive Notes

- The state-note reconciling the stale spec (note 64) against the authoritative roadmap milestone remains excellent — it correctly flags `close()` as dead code and names the roadmap as source of truth.
- Localization is handled ARB-first with key reuse and an explicit, correct regen command.
- Architecture-faithful: provider/interface in the package, concrete in `lib/`, no domain leakage.
- Commit split is sensible (contract + strings, then UI + trigger).

## Verdict

The plan is well-structured and almost entirely correct, but it carries forward — unchanged — the single critical defect from review-1: Task 5 adds a live `ref.read` consumer of a throw-by-default provider that this milestone deliberately never overrides on the production-routed `MeditationSessionScreen`, so stopping any meditation session throws `UnimplementedError`. Because review-1's required fix was not applied, this plan cannot pass. Resolve Critical Issue #1 (preferably fix option (a): override `meditationSessionCoordinatorProvider` with the Task 2 placeholder in `buildSession()`, and amend Task 2 accordingly) before implementation.
