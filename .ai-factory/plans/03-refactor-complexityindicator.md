# Plan: Refactor ComplexityIndicator

## Context
Replace the `SingleChildScrollView` workaround in `ComplexityIndicator` with `ClipRect` + `OverflowBox` to eliminate a redundant `Scrollable` per list cell while preserving identical visual behavior.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Replace scroll wrapper

- [x] **Task 1: Swap SingleChildScrollView for ClipRect + OverflowBox**
  Files: `packages/breath_module/lib/src/Widgets/ComplexityIndicator.dart`
  In the `build` method, replace the `SingleChildScrollView` (lines 41-55) with the following widget tree inside the outer `SizedBox(width: _revealWidth, height: _iconSize)`:

  ```
  ClipRect
  └── OverflowBox(
        alignment: Alignment.centerLeft,
        maxWidth: _totalWidth,
        maxHeight: _iconSize,
      )
      └── Row(mainAxisSize: MainAxisSize.min, children: [...])
  ```

  `alignment: Alignment.centerLeft` anchors the icon row to the left edge so the reveal clips from the right — same visual as before. Remove the `SingleChildScrollView` and its `NeverScrollableScrollPhysics` import if no longer needed. Update the comment above the widget to briefly explain why `OverflowBox` is used (layout-time constraint override to avoid overflow warning, `ClipRect` clips at paint time).

- [x] **Task 2: Smoke-check both call sites**
  Files: `packages/breath_module/lib/src/BreathSessionsList/Views/BreathSessionListCell.dart`, `packages/breath_module/lib/src/BreathSessionConstructor/Views/ConstructorFooter.dart`
  Read both files that use `ComplexityIndicator` to confirm no constructor arguments changed and no additional adaptation is needed. The public API (`complexity`, `width`) stays the same, so this task is verification only — no edits expected.
