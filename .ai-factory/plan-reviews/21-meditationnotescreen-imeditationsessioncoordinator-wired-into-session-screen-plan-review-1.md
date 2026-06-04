# Plan Review: MeditationNoteScreen + IMeditationSessionCoordinator wired into session screen

**Plan:** `.ai-factory/plans/21-meditationnotescreen-imeditationsessioncoordinator-wired-into-session-screen.md`
**Files Reviewed:** 7 (plan + 6 codebase targets)
**Risk Level:** 🔴 High

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** ✅ Aligned. The plan respects the domain/module boundary — the throw-by-default `meditationSessionCoordinatorProvider` lives in the package alongside the interface, mirroring `meditationSessionViewModelProvider`. The concrete coordinator stays in `lib/`. No boundary violation.
- **Rules (`.ai-factory/RULES.md`):** WARN — file not present. No explicit rule set to check against.
- **Roadmap (`.ai-factory/ROADMAP.md`):** ✅ Linked. Matches the milestone at ROADMAP line 75 ("`MeditationNoteScreen` + `IMeditationSessionCoordinator` wired into session screen"). The plan correctly defers the concrete coordinator and `buildSession()` override to the later milestone (line 78). The state-note's reference to "ROADMAP line 77" is approximately correct (the later wiring milestone is the "Concrete `MeditationNoteService` + `MeditationSessionCoordinator` + full wire in `MeditationModule.buildSession()`" entry).

## Critical Issues

### 1. 🔴 Stopping a meditation session will throw `UnimplementedError` at runtime

This is the central defect and it ships *in this milestone*.

- Task 5 adds, inside `MeditationSessionScreen.build()`, a live read on the `active → idle` transition:
  ```dart
  ref.read(meditationSessionCoordinatorProvider).onSessionStopped()
  ```
- Task 1 defines `meditationSessionCoordinatorProvider` as **throw-by-default** (`throw UnimplementedError(...)`).
- Task 2 **explicitly forbids** overriding it: *"Do NOT wire this coordinator into `MeditationModule.buildSession()` — that is out of scope."* The roadmap confirms the `overrideWithValue` lands in a later milestone.

But `MeditationSessionScreen` is **live in production today** — `lib/router.dart:65` routes to `MeditationModule.buildSession(context, poseId: poseId)`, and `buildSession()` overrides only `meditationSessionViewModelProvider`, never `meditationSessionCoordinatorProvider`.

Consequence: the moment a user taps stop, `vm.stop()` sets status `idle`, the new listener fires, `ref.read(meditationSessionCoordinatorProvider)` re-throws the cached `UnimplementedError`, and the stop action errors instead of completing. Unlike `meditationSessionViewModelProvider` (which is *always* overridden in `buildSession`), the coordinator provider is read but never overridden — that asymmetry is the bug. The feature regresses now and only self-heals two milestones later.

**Fix options (pick one):**
- **(a) Recommended — override now with the placeholder.** In `buildSession()`, add `meditationSessionCoordinatorProvider.overrideWithValue(MeditationSessionCoordinator(context))`, using the Task 2 placeholder whose `onSessionStopped()` is a safe no-op. This keeps the listener working as a no-op until the real implementation arrives, at zero behavioral cost. It contradicts Task 2's "do not wire" instruction, but that instruction is precisely what creates the crash. (Requires `meditation_module` import already present in `MeditationModule.dart` — it is.)
- **(b)** Make the default provider return a no-op coordinator instead of throwing. Diverges from the `meditationSessionViewModelProvider` throw-by-default convention, so less consistent.
- **(c)** Defer Task 5 (the `ref.listen`) to the later wiring milestone, so the live consumer and its override land together. Cleanest separation, but leaves this milestone with only dead package code.

Whichever path is chosen, the plan must resolve the contradiction between "add a live consumer of the provider" and "don't override the provider."

## Minor Issues / Notes

- **Task 2 — unused `context` field.** After removing the `close()` body and the `go_router` import, the `final BuildContext context;` field becomes unused. This is *not* analyzer-flagged (`unused_field` only targets private fields), and `package:flutter/widgets.dart` is still required for the `BuildContext` type, so the file stays analyzer-clean as the plan claims. No action needed; just noting the field is dead until the later milestone. (If fix option (a) is taken, the field is used again by `onSessionStopped()`'s eventual navigation — but in this milestone it remains a no-op.)
- **Task 1 — Riverpod 3.0 API.** `Provider<IMeditationSessionCoordinator>((_) {...})` from `package:flutter_riverpod/flutter_riverpod.dart` is valid in flutter_riverpod ^3.0.0 (the package's pinned version) and matches the existing `NotifierProvider` usage in `MeditationSessionViewModel.dart`. ✅
- **Task 4 — `withValues(alpha:)`.** Flutter 3.27+ API. Confirm the toolchain is recent enough; the spec (note 64) mandates it, so this is inherited, not introduced by the plan. Low risk.
- **Verified correct:** barrel export path (`IMeditationSessionCoordinator.dart` already exported, line 11; `MeditationNoteScreen` export added in Task 4); `AppLocalizations` is exported from `package:mind_l10n/mind_l10n.dart` and the `AppLocalizations.of(context)!` pattern matches `MeditationListScreen.dart`; `ok`/`cancel` keys exist in both `app_en.arb` and `app_ru.arb`; l10n config (`synthetic-package: false`, output `app_localizations.dart`); `ref.listen` with `.select` is valid in a `ConsumerStatefulWidget.build()`; the only `active → idle` transition source is `vm.stop()`, so the listener fires exactly once per stop.

## Positive Notes

- The state-note at the top of the plan is excellent — it correctly identifies that the spec predates the interface, flags `close()` as dead code, and names the roadmap as authoritative. This is the kind of reconciliation that prevents blind spec-following.
- Localization handled properly: ARB-first, reuse of existing keys, explicit regeneration command with the correct working directory and config.
- Architecture-faithful: provider/interface in the package, concrete in `lib/`, no domain leakage into the module.
- Commit plan is sensibly split (contract+strings, then UI+trigger).

## Verdict

The plan is well-structured and almost entirely correct, but Critical Issue #1 makes it ship a user-facing runtime regression: stopping any meditation session throws because the live `ref.read` consumer added in Task 5 reads a throw-by-default provider that this milestone deliberately never overrides on the production-routed screen. This must be resolved before implementation — preferably by overriding the provider with the Task 2 placeholder coordinator in `buildSession()` (fix option a).
