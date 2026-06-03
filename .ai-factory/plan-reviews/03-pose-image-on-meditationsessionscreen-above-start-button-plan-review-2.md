# Plan Review 2: Pose image on MeditationSessionScreen above start button

**Plan:** `.ai-factory/plans/03-pose-image-on-meditationsessionscreen-above-start-button.md`
**Files Reviewed:** 5 (state, ViewModel, screen, module wiring, router) + assets + pubspec + RULES/ROADMAP/ARCHITECTURE
**Risk Level:** 🟢 Low — both blocking defects from review 1 are resolved; no new issues found.

---

## Context Gates

- **Architecture (`ARCHITECTURE.md`)** — present. The package/`lib` module boundary is respected: presentation (state, VM, screen) lives in `packages/meditation_module/`, wiring stays in `lib/MeditationModule/MeditationModule.dart`. No boundary violation. No new dependency added.
- **Rules (`RULES.md`)** — **PASS.** The prior ERROR (external field mutation `vm.._poseId = poseId`) is gone. Task 2 now injects `poseId` via the `MeditationSessionViewModel` **constructor**, and Task 2 explicitly forbids the private-field approach. This satisfies RULES.md line 9 (constructor injection) and matches the established `BreathModule.buildSession` pattern.
- **Roadmap (`ROADMAP.md`)** — linked. Implements the milestone "Pose image on `MeditationSessionScreen` above start button". The roadmap text's sketch defects (`vm.._poseId`, raw `$poseId`) are no longer copied into the plan.

---

## Review-1 Blocker Verification

### 1. `_poseId` library-private compile error — RESOLVED ✅

Task 2 now reads: *"Add a constructor `MeditationSessionViewModel({required this.poseId});` with `final String poseId;` … Do **not** add a private `_poseId` field — a library-private member would not be assignable from the host-app wiring file and would not compile."* Task 3 constructs `MeditationSessionViewModel(poseId: poseId)` from the `overrideWith` factory, where `poseId` is in scope (the `buildSession({required String poseId})` param). Verified against `lib/MeditationModule/MeditationModule.dart:23,28` — the current `MeditationSessionViewModel()` call is the exact line Task 3 updates, and `poseId` is already threaded to `MeditationModuleStateChannel`. Compiles cleanly; convention-correct.

### 2. `half_lotus` invisible-image defect — RESOLVED ✅

Task 4 builds the path as `meditation-pose-${poseId.replaceAll('_', '-')}.png`, identical to the shipped sibling `MeditationListCell.dart:17`. Verified on disk: all six assets exist with hyphens (`meditation-pose-half-lotus.png`, etc.), and the ids in `MeditationPoses.dart` use underscores (`half_lotus`). Normalization correctly maps `half_lotus → half-lotus`. The plan's Notes section (line 12) now states the id/asset hyphen-vs-underscore distinction correctly.

---

## Additional Verification

- **Asset declaration** — `pubspec.yaml:114` declares `assets/images/modules/meditation/`. The bare path (no `package:` prefix) resolves against the host-app bundle, matching how `MeditationListCell` already loads the same assets. Plan note (line 40) states this correctly.
- **No other consumers break** — searched the whole repo: the only real-code call sites for `MeditationSessionState.initial()` (VM line 18) and `MeditationSessionViewModel()` (wiring line 28) are exactly the two updated by Tasks 2–3. The `MeditationSessionState({required this.status})` constructor gains a required `poseId`; no other code constructs it. No test files reference `MeditationSession` (note 96 is an unimplemented test *plan*), so adding required params breaks nothing.
- **Dart validity** — `const MeditationSessionState.initial({required String poseId}) : status = …, poseId = poseId;` is valid (left = field, right = param). `copyWith({String? poseId})` with `poseId ?? this.poseId` correctly preserves `poseId` across `start()`/`stop()`.
- **Route contract** — `lib/router.dart:64` does `state.extra as String`, so `poseId` is always non-null/non-empty from the route; dropping the empty-string fallback (plan note line 13) is safe.
- **Riverpod** — passing a constructor arg to a `Notifier` subclass instantiated inside `overrideWith(() => …)` is valid; the base `Notifier` has no required constructor args.

---

## Non-blocking Notes

- **Narrow `select` on `poseId`** (Task 4) — correct and efficient. `poseId` never mutates after init, so this select effectively never re-fires for it. Harmless, slightly more machinery than strictly needed; acceptable and consistent with the existing `status` watch style.
- **`errorBuilder` as safety net** — kept for genuinely unknown ids only, no longer papering over the underscore mismatch. Good.

## Positive Notes

- Minimal, correct file set; respects the package/`lib` boundary.
- Both review-1 fixes applied precisely and the rationale baked into the task text (prevents regression during implementation).
- Reuses the established `Image.asset` + `errorBuilder` + sizing convention and the proven `replaceAll('_', '-')` normalization from the sibling cell.
- Constructor injection matches `BreathModule` and satisfies RULES.md.

---

## Verdict

The plan correctly resolves both blocking defects from review 1, and re-verification against the live codebase (file paths, asset names, pubspec declaration, route contract, consumer call sites, Dart validity) surfaces no remaining issues. Ready to implement.

PLAN_REVIEW_PASS
