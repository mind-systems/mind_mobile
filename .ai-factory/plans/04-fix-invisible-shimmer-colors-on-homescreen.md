# Plan: Fix invisible shimmer colors on HomeScreen

## Context
HomeScreen shimmer placeholders use `colorScheme.surfaceContainerHighest` / `colorScheme.surface`, which `AppTheme` never sets — Flutter auto-generates values near-identical to the background, making the shimmer invisible. Switch to the explicitly defined `theme.cardColor` / `theme.highlightColor`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Fix shimmer colors

- [x] **Task 1: Fix `_SuggestionsShimmer` colors**
  Files: `lib/HomeModule/Presentation/HomeScreen/Widgets/SuggestionsCard.dart`
  Inside `_SuggestionsShimmer.build()` (lines 73-74), replace the two color assignments:
  `final base = theme.colorScheme.surfaceContainerHighest;` → `final base = theme.cardColor;`
  `final highlight = theme.colorScheme.surface;` → `final highlight = theme.highlightColor;`
  No other changes. Mirrors the correct pattern in `BreathSessionListSkeletonCell` (`packages/breath_module/lib/src/BreathSessionsList/Views/BreathSessionListSkeletonCell.dart`).

- [x] **Task 2: Fix `_StatsShimmer` colors**
  Files: `lib/HomeModule/Presentation/HomeScreen/Widgets/StatsCard.dart`
  Inside `_StatsShimmer.build()` (lines 66-67), apply the identical replacement:
  `final base = theme.colorScheme.surfaceContainerHighest;` → `final base = theme.cardColor;`
  `final highlight = theme.colorScheme.surface;` → `final highlight = theme.highlightColor;`
  No structural changes.
