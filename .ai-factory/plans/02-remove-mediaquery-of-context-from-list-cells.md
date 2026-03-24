# Plan: Remove `MediaQuery.of(context)` from list cells

## Context
Replace `MediaQuery.of(context).devicePixelRatio` with the granular `MediaQuery.devicePixelRatioOf(context)` accessor in the two breath session list cell widgets to eliminate unnecessary `InheritedWidget` subscriptions that cause rebuilds on unrelated `MediaQuery` changes (keyboard, orientation, padding).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Replace MediaQuery usage

- [x] **Task 1: Replace MediaQuery in BreathSessionListCell**
  Files: `packages/breath_module/lib/src/BreathSessionsList/Views/BreathSessionListCell.dart`
  On line 18, change `1 / MediaQuery.of(context).devicePixelRatio` to `1 / MediaQuery.devicePixelRatioOf(context)`. No import changes needed — `MediaQuery` is already available via the existing Flutter imports.

- [x] **Task 2: Replace MediaQuery in BreathSessionListSkeletonCell**
  Files: `packages/breath_module/lib/src/BreathSessionsList/Views/BreathSessionListSkeletonCell.dart`
  On line 25, change `1 / MediaQuery.of(context).devicePixelRatio` to `1 / MediaQuery.devicePixelRatioOf(context)`. No import changes needed.
