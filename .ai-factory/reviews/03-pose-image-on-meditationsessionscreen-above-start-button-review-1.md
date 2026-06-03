# Code Review: Pose image on MeditationSessionScreen above start button

**Plan:** `.ai-factory/plans/03-pose-image-on-meditationsessionscreen-above-start-button.md`
**Files changed:** 4 (state, ViewModel, module wiring, screen)
**Risk Level:** 🟢 Low — clean implementation, matches the plan and resolves both prior plan-review blockers.

---

## Scope verification

`git diff HEAD` covers exactly the four files in the plan. No stray edits, no unrelated changes.

Call-site sweep (`MeditationSessionState`, `.initial(`, `MeditationSessionViewModel(`) confirms the signature changes are fully propagated:
- `MeditationSessionState({required status, required poseId})` — only constructed via the `.initial` / `copyWith` paths inside the package; no external callers pass the old positional shape.
- `MeditationSessionState.initial(...)` — sole caller is `MeditationSessionViewModel.build()`, updated to pass `poseId`.
- `MeditationSessionViewModel(...)` — sole instantiation is `MeditationModule.buildSession`, updated to `MeditationSessionViewModel(poseId: poseId)`.
- `MeditationModuleStateChannel` consumes `MeditationSessionState` only via `status`/stream — unaffected by the added `poseId` field.
- No test references `MeditationSession*`, so no test breakage.

## Correctness checks

- **Both prior blockers resolved.** `poseId` is injected through the public Notifier constructor (no library-private field — compiles across the package/host-app boundary, satisfies the constructor-injection rule). The asset path normalizes `_` → `-` via `poseId.replaceAll('_', '-')`, so `half_lotus` correctly resolves to `meditation-pose-half-lotus.png`, matching the sibling `MeditationListCell.dart:17`.
- **Asset resolution.** The path has no `package:` prefix and resolves against the host app bundle, where `assets/images/modules/meditation/` is declared in `pubspec.yaml:114`. All six on-disk assets (`chair`, `easy`, `half-lotus`, `lotus`, `savasana`, `seiza`) line up with the six pose ids after normalization.
- **`copyWith` preserves `poseId`** across `start()`/`stop()` transitions (both go through `copyWith(status: ...)`, leaving `poseId` intact). The narrow `select((s) => s.poseId)` is correct; since `poseId` never mutates post-init the selector simply never re-fires — harmless.
- **`errorBuilder` signature** `(context, error, stackTrace)` is the correct `ImageErrorWidgetBuilder` shape. Returning `SizedBox.shrink()` collapses the image child only; the enclosing `SizedBox(240×240)` still reserves space, keeping button position stable whether or not the image loads — acceptable, consistent layout.
- **Layout.** `Center > Column(mainAxisSize: min)` centers the image + 40px gap + 80×80 button vertically and horizontally (Column cross-axis default is center). No overflow risk for the fixed 240+40+80 = 360px content on any normal screen.

## Findings

None.

REVIEW_PASS
