# Plan: Declare pose assets + meditation list cell with image

## Context
Make meditation pose images loadable and replace the bare `ListTile` in the meditation list with a custom cell that shows the localized pose title and the corresponding pose image below it, left-aligned.

**Naming caveat (must respect):** pose ids in `MeditationPoses.dart` use underscores (`easy`, `lotus`, `half_lotus`, `seiza`, `chair`, `savasana`), but the asset files on disk use hyphens — notably `meditation-pose-half-lotus.png` (hyphen), not `meditation-pose-half_lotus.png`. A raw `$poseId` interpolation therefore breaks the `half_lotus` cell. The cell must normalize underscores to hyphens when building the asset path.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Asset declaration

- [x] **Task 1: Declare the meditation images asset directory**
  Files: `pubspec.yaml`
  Under `flutter: > assets:`, add a new entry `- assets/images/modules/meditation/` directly after the existing `- assets/images/modules/home/` line. Match the existing **three-space** list indentation used by the surrounding entries (`   - assets/images/modules/home/`). Flutter's directory-asset declaration is non-recursive, so the existing `- assets/images/` line does not cover this subdirectory — the explicit entry is required to make the pose PNGs loadable by `Image.asset`. (No package-scoped declaration is needed — assets are declared in the app's root `pubspec.yaml`, and the cell widget loads them from the default app bundle without a `package:` argument.)

### Phase 2: List cell widget

- [x] **Task 2: Create the `MeditationListCell` widget**
  Files: `packages/meditation_module/lib/src/MeditationList/Views/MeditationListCell.dart`
  Create a new `StatelessWidget` named `MeditationListCell` with three fields: `final String poseId`, `final String title`, `final VoidCallback? onTap`, plus a const constructor (`required poseId`, `required title`, optional `onTap`, `super.key`).
  Build tree: `InkWell(onTap: onTap, child: Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...])))`.
  Column children: `Text(title, style: Theme.of(context).textTheme.bodyLarge)`, then `const SizedBox(height: 8)`, then the pose image.
  **Asset path (Guard — fixes the underscore/hyphen mismatch):** build the filename by replacing underscores with hyphens in the id:
  ```dart
  final assetName = 'meditation-pose-${poseId.replaceAll('_', '-')}.png';
  // -> Image.asset('assets/images/modules/meditation/$assetName', height: 120, fit: BoxFit.contain)
  ```
  This makes `half_lotus` resolve to the on-disk `meditation-pose-half-lotus.png`. Do **not** interpolate the raw `poseId` — that produces `meditation-pose-half_lotus.png`, which does not exist and renders a broken-image box.
  Add an `errorBuilder` on the `Image.asset` that returns a `SizedBox(height: 120)` placeholder, so a future pose id without a matching PNG degrades gracefully instead of hard-failing.
  Import only `package:flutter/material.dart`.

- [x] **Task 3: Export the cell from the package barrel** (depends on Task 2)
  Files: `packages/meditation_module/lib/meditation_module.dart`
  Add `export 'src/MeditationList/Views/MeditationListCell.dart';` to the barrel, grouped with the other `MeditationList/` exports.

### Phase 3: Wire into the list screen

- [x] **Task 4: Replace the `ListTile` with `MeditationListCell`** (depends on Task 2)
  Files: `packages/meditation_module/lib/src/MeditationList/MeditationListScreen.dart`
  In the `ListView.builder` `itemBuilder`, replace the `ListTile(...)` with:
  ```dart
  MeditationListCell(
    poseId: pose.id,
    title: meditationPoseTitle(l10n, pose.id),
    onTap: () =>
        ref.read(meditationListViewModelProvider.notifier).onPoseTap(pose.id),
  )
  ```
  Add the import `import 'Views/MeditationListCell.dart';`. Keep the existing `pose`, `l10n`, and provider usage unchanged.

## Verification
After implementation, run the app, navigate to the meditation list, and confirm **all six** cells (especially `half_lotus`) show the localized pose title with the matching pose image rendered below it, left-aligned — no broken-image boxes.
