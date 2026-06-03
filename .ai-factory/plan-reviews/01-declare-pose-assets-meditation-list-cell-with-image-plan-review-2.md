# Plan Review 2: Declare pose assets + meditation list cell with image

**Plan:** `01-declare-pose-assets-meditation-list-cell-with-image.md`
**Files Reviewed:** 4 (plan + 3 target/context files) + pubspec + asset dir
**Risk Level:** 🟢 Low — all blockers from review-1 are resolved.

## Context Gates
- `.ai-factory/ARCHITECTURE.md` — no boundary impact. The cell stays inside `packages/meditation_module/`, imports only `package:flutter/material.dart`, and consumes DTO fields (`pose.id`, `title`) — no domain or Riverpod leakage into the widget. WARN: none.
- `.ai-factory/RULES.md` — no explicit convention violations detected.
- Roadmap linkage — not evaluated (plan-stage review).

## Review of prior findings (review-1)
All three issues raised in review-1 are now addressed in the plan text:

1. **Underscore/hyphen mismatch (was BLOCKER)** — RESOLVED. The naming caveat is documented up front (lines 5–6), and Task 2 now mandates `'meditation-pose-${poseId.replaceAll('_', '-')}.png'` with an explicit note not to interpolate the raw id. Verified against disk: `meditation-pose-half-lotus.png` exists (hyphen), and `replaceAll('_','-')` maps `half_lotus → half-lotus`. All six ids in `kMeditationPoses` (`easy, lotus, half_lotus, seiza, chair, savasana`) now resolve to existing PNGs.
2. **Indentation claim (was minor)** — RESOLVED. Task 1 now says "three-space" and the example `   - assets/images/modules/home/` matches the actual pubspec, which I confirmed uses three-space list indentation (`···-`).
3. **Missing errorBuilder (was optional)** — RESOLVED. Task 2 now requires an `errorBuilder` returning a `SizedBox(height: 120)` placeholder.

## Verified Correct (this pass)
- **Asset directory & files** — `assets/images/modules/meditation/` exists with exactly the six expected PNGs. No hidden missing-file work.
- **pubspec entry required** — Flutter directory-asset declarations are non-recursive, so `- assets/images/` does not cover the subdirectory; the explicit `- assets/images/modules/meditation/` is needed. Insertion point (after `- assets/images/modules/home/`) is accurate.
- **No `package:` argument** — assets are declared in the app root `pubspec.yaml`, so `Image.asset(...)` called from package code resolves against the default app bundle. Correct; no package-scoped declaration needed.
- **New file path** — `packages/meditation_module/lib/src/MeditationList/Views/MeditationListCell.dart` is consistent with the package layout; the `Views/` subdirectory is new (created implicitly), which is fine.
- **Barrel export** (Task 3) — path `src/MeditationList/Views/MeditationListCell.dart` is correct and groups cleanly with the existing `MeditationList/` exports in `meditation_module.dart`.
- **List screen wiring** (Task 4) — the replacement preserves the current `pose.id`, `l10n`, and `onPoseTap(pose.id)` usage exactly as in `MeditationListScreen.dart`; relative import `Views/MeditationListCell.dart` is correct relative to the screen file. `meditationPoseTitle(l10n, pose.id)` already exists in `MeditationPoses.dart` — no l10n changes required.
- **Module boundary** — widget imports only Flutter material; no domain leakage. Consistent with project module-system rules.

## Minor Notes (non-blocking)
- Package-isolated widget tests (running the package without the app shell) would not find the app-bundle asset, but the `errorBuilder` degrades gracefully and the plan's Settings declare `Testing: no`. No action needed.
- Task 2 fixes image `height: 120` while the errorBuilder placeholder is also `height: 120` — consistent, good. No magic-number concern worth blocking on for a single-use cell.

## Verdict
The plan is structurally sound, respects the package architecture, and every issue from review-1 has been corrected and verified against the actual codebase. Ready to implement.

PLAN_REVIEW_PASS
