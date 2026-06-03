# Plan: Section header "Позы" + hairline dividers on meditation list

## Context
Add a "Poses"/"Позы" section header at the top of the meditation list and 1-physical-pixel hairline dividers between pose cells, mirroring the breath session list styling.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Notes / Assumptions
- The milestone says the new header must be an **exact copy of `BreathSessionListSectionHeader`**. The current real widget at `packages/breath_module/lib/src/BreathSessionsList/Views/BreathSessionListSectionHeader.dart` uses `style: theme.textTheme.labelLarge?.copyWith(color: theme.textTheme.bodySmall?.color)` — this differs slightly from the snippet in the spec note (which used `α0.5`). **Follow the real widget** to keep the two lists visually identical.
- `MeditationListState.poses` is `List<MeditationPoseDTO>`; the screen already maps poses via `MeditationListCell` + `meditationPoseTitle(l10n, pose.id)`.
- Meditation ARB keys are plain string entries (no `@`-metadata block), e.g. `meditationPoseEasy`. Add the new key in the same simple form.

## Tasks

### Phase 1: Localization

- [x] **Task 1: Add `meditationPoseSectionTitle` ARB key**
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`
  Add key `meditationPoseSectionTitle` to both ARB files alongside the other `meditationPose*` entries: EN `"Poses"`, RU `"Позы"`. Match the existing plain-string formatting (no `@`-metadata block).

- [x] **Task 2: Regenerate `AppLocalizations`** (depends on Task 1)
  Files: `packages/mind_l10n/` (generated)
  Run the l10n codegen so `AppLocalizations.meditationPoseSectionTitle` becomes available (`flutter gen-l10n` per the mind_l10n package config). Confirm the getter exists in the generated localizations before continuing.

### Phase 2: Section header widget

- [x] **Task 3: Create `MeditationListSectionHeader`**
  Files: `packages/meditation_module/lib/src/MeditationList/Views/MeditationListSectionHeader.dart`
  Create a `StatelessWidget` that is an exact copy of `BreathSessionListSectionHeader`: a required `final String title`, `const` constructor, and a `build` that returns `ColoredBox(color: theme.cardColor.withValues(alpha: 0.3))` wrapping `Padding(EdgeInsets.symmetric(horizontal: 16, vertical: 12))` wrapping `Text(title, style: theme.textTheme.labelLarge?.copyWith(color: theme.textTheme.bodySmall?.color))`. Import only `package:flutter/material.dart`.

- [x] **Task 4: Export the new widget from the barrel** (depends on Task 3)
  Files: `packages/meditation_module/lib/meditation_module.dart`
  Add `export 'src/MeditationList/Views/MeditationListSectionHeader.dart';` next to the existing `MeditationListCell` export.

### Phase 3: Screen wiring

- [x] **Task 5: Insert header + hairline dividers in `MeditationListScreen`** (depends on Tasks 2, 3)
  Files: `packages/meditation_module/lib/src/MeditationList/MeditationListScreen.dart`
  - Import `Views/MeditationListSectionHeader.dart`.
  - Change `itemCount` to `state.poses.length + 1`.
  - In `itemBuilder`: when `index == 0`, return `MeditationListSectionHeader(title: l10n.meditationPoseSectionTitle)`.
  - Otherwise compute `final poseIndex = index - 1;` and use `state.poses[poseIndex]`.
  - Compute the hairline thickness as `1.0 / MediaQuery.devicePixelRatioOf(context)` and `final showDivider = poseIndex < state.poses.length - 1;`.
  - Return a `Column(mainAxisSize: MainAxisSize.min, ...)` containing the existing `MeditationListCell` (unchanged props: `poseId`, `title`, `onTap`), followed — only when `showDivider` — by `Padding(EdgeInsets.symmetric(horizontal: 16), child: Container(height: pixel, color: Theme.of(context).dividerColor))`. No divider before the first cell or after the last.

## Verify
Run the app → open the meditation list: a "Poses"/"Позы" header sits at the top over a muted `cardColor`-tinted background, hairline dividers separate the pose cells with no divider after the last cell, and pose taps still navigate as before.
