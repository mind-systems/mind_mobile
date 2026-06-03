# Code Review: Declare pose assets + meditation list cell with image

**Plan:** `01-declare-pose-assets-meditation-list-cell-with-image.md`
**Scope reviewed:** `pubspec.yaml`, `MeditationListCell.dart` (new), `MeditationListScreen.dart`, `meditation_module.dart` barrel.
**Risk Level:** 🟢 Low — all four tasks implemented as specified; no correctness or runtime issues found.

## What was changed
- `pubspec.yaml` — added `- assets/images/modules/meditation/` with consistent three-space list indentation, placed between the `home/` and `audio/` entries.
- `MeditationListCell.dart` — new `StatelessWidget` (`poseId`, `title`, `onTap?`, const ctor with `super.key`). `InkWell` → `Padding(16h/12v)` → `Column(crossAxisAlignment: start)` with `Text(title, bodyLarge)`, `SizedBox(height: 8)`, and `Image.asset(...)`.
- `MeditationListScreen.dart` — `ListTile` replaced with `MeditationListCell`; relative import added.
- `meditation_module.dart` — cell exported, grouped with the other `MeditationList/` exports.

## Correctness verification

### Asset path / id normalization (the prior BLOCKER) — RESOLVED
The cell builds `'meditation-pose-${poseId.replaceAll('_', '-')}.png'`. Cross-checked every id in `kMeditationPoses` against the files on disk:

| poseId | resolved filename | on disk |
|---|---|---|
| `easy` | meditation-pose-easy.png | ✓ |
| `lotus` | meditation-pose-lotus.png | ✓ |
| `half_lotus` | meditation-pose-half-lotus.png | ✓ |
| `seiza` | meditation-pose-seiza.png | ✓ |
| `chair` | meditation-pose-chair.png | ✓ |
| `savasana` | meditation-pose-savasana.png | ✓ |

All six resolve to existing assets — including the previously broken `half_lotus`. No broken-image box.

### Other checks
- **errorBuilder present** — `Image.asset` returns `SizedBox(height: 120)` on failure, so a future pose without a matching PNG degrades gracefully and keeps row height stable.
- **Asset declaration required & correct** — Flutter directory-asset declarations are non-recursive, so the existing `- assets/images/` line does not cover the subdirectory; the explicit entry is needed. Indentation matches the surrounding three-space list entries (YAML-valid and consistent).
- **No `package:` argument** — assets are declared in the app-root `pubspec.yaml`, and `Image.asset` from package code resolves against the default app bundle. Correct; no package-scoped declaration needed.
- **Screen wiring** — `pose.id`, `meditationPoseTitle(l10n, pose.id)`, and `onPoseTap(pose.id)` are preserved exactly; `meditationPoseTitle` already exists, so no l10n changes required. The relative import `Views/MeditationListCell.dart` is correct relative to the screen file.
- **Barrel export** — path is accurate and consistent with the package layout.
- **Module boundary** — the cell imports only `package:flutter/material.dart`; no domain or Riverpod leakage. Compliant with the package architecture.

## Minor notes (non-blocking, no action required)
- Package-isolated widget tests (without the app shell) would not find the app-bundle asset, but the `errorBuilder` keeps such a test from crashing and the plan declares `Testing: no`.
- `height: 120` is duplicated between the image and its error placeholder — intentional and consistent for a single-use cell; not worth extracting.

REVIEW_PASS
