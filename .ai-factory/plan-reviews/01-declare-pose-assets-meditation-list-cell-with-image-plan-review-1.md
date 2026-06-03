# Plan Review: Declare pose assets + meditation list cell with image

**Plan:** `01-declare-pose-assets-meditation-list-cell-with-image.md`
**Risk Level:** 🔴 High — one guaranteed runtime asset-load failure baked into the plan.

## Context Gates
- `.ai-factory/ARCHITECTURE.md` — not consulted for this review (no boundary impact; cell stays inside the package). The plan respects the module boundary: the cell is added under `packages/meditation_module/`, imports only `package:flutter/material.dart`, and works with DTOs (`pose.id`, `title`) — no domain leakage. WARN: none.
- `.ai-factory/RULES.md` — no explicit convention violations detected.
- Roadmap linkage — not evaluated (plan-stage review).

## Critical Issues

### 1. Pose id ↔ asset filename mismatch breaks `half_lotus` (BLOCKER)
The pose ids in `packages/meditation_module/lib/src/Models/MeditationPoses.dart` use **underscores**:
```
easy, lotus, half_lotus, seiza, chair, savasana
```
But the asset files on disk in `assets/images/modules/meditation/` use a **hyphen** for the two-word pose:
```
meditation-pose-easy.png
meditation-pose-lotus.png
meditation-pose-half-lotus.png   ← hyphen, not underscore
meditation-pose-seiza.png
meditation-pose-chair.png
meditation-pose-savasana.png
```

Task 2 mandates `Image.asset('assets/images/modules/meditation/meditation-pose-$poseId.png', ...)` **with an explicit Guard forbidding any transformation of the id**. For `poseId == 'half_lotus'` this interpolates to `meditation-pose-half_lotus.png`, which **does not exist** — Flutter will throw a missing-asset exception and render the broken-image error box for that one cell. Every other pose happens to match, which makes the bug easy to miss in a quick smoke test.

**Fix options (pick one, and update the Guard accordingly):**
- **Preferred — normalize in the widget:** build the path from `poseId.replaceAll('_', '-')`, i.e. `meditation-pose-${poseId.replaceAll('_', '-')}.png`. The current Guard ("no transformation of the id") directly contradicts this and must be rewritten.
- **Alternative — rename the asset file** `meditation-pose-half-lotus.png` → `meditation-pose-half_lotus.png` so the raw id interpolation works. (Add a plan task for the rename; otherwise the file rename is undeclared work.)

Either way the plan currently ships a guaranteed broken cell. This is the one must-fix item.

## Minor Issues

### 2. Incorrect indentation claim in Task 1
Task 1 says to "keep the existing **two-space** list indentation." The actual `pubspec.yaml` assets list uses **three-space** indentation:
```
  assets:
   - assets/images/
   - assets/images/modules/home/
   - assets/audio/
```
The intent ("match surrounding entries") is right, but the stated "two-space" is factually wrong. An implementer who follows the literal instruction over the surrounding context could produce inconsistent (though YAML-valid) indentation. Reword to "match the existing three-space list indentation."

### 3. No `errorBuilder` / fallback for a missing pose image
Once issue #1 is fixed all six assets resolve, so this is not blocking. But `Image.asset` has no `errorBuilder`, so any future pose added to `kMeditationPoses` without a matching PNG will hard-fail with a broken-image box. Consider adding an `errorBuilder` returning a sized placeholder for resilience. Optional.

## Verified Correct
- The new `pubspec.yaml` asset entry **is** required: Flutter's directory-asset declaration is non-recursive, so the existing `- assets/images/` line does not pick up `assets/images/modules/meditation/`. Adding the explicit directory is correct.
- All six PNGs exist on disk, so no missing-file work is hidden (modulo the naming mismatch in #1).
- Loading without a `package:` argument is correct: assets are declared in the app root `pubspec.yaml`, and `Image.asset` from inside the package resolves against the root bundle. The plan's reasoning here is sound.
- Task 4's replacement preserves existing `pose.id`, `l10n`, and `onPoseTap(pose.id)` usage — matches the current `MeditationListScreen.dart` exactly.
- Relative import path `Views/MeditationListCell.dart` is correct relative to `MeditationListScreen.dart`.
- Barrel export path (Task 3) and the new file path (Task 2) are accurate and consistent with the package layout.
- Module-boundary compliance: widget imports only `package:flutter/material.dart`, no domain/Riverpod leakage into the cell.

## Verdict
The plan is structurally sound and respects the package architecture, but it cannot ship as written: the explicit "no transformation of the id" Guard plus the underscore/hyphen filename mismatch guarantees a broken `half_lotus` cell at runtime. Resolve issue #1 (and ideally #2) before implementation.
