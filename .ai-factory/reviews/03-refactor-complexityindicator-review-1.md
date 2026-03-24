# Review: Refactor ComplexityIndicator

**Plan:** `.ai-factory/plans/03-refactor-complexityindicator.md`
**Files changed:** `packages/breath_module/lib/src/Widgets/ComplexityIndicator.dart`

## Change summary

Replaced `SingleChildScrollView` + `NeverScrollableScrollPhysics` with `ClipRect` → `OverflowBox(alignment: centerLeft, maxWidth: _totalWidth, maxHeight: _iconSize)` → `Row`. Removes per-cell `Scrollable` overhead (ScrollPosition, ScrollController, viewport) while preserving identical visual behavior.

## Layout correctness

- `SizedBox(width: _revealWidth)` constrains the parent box.
- `OverflowBox` sizes itself to the parent (`_revealWidth × _iconSize`) but passes `maxWidth: 100` to the `Row`, so `RenderFlex` never sees a constraint violation — no overflow warning.
- `alignment: Alignment.centerLeft` anchors the Row's left edge to the parent's left edge, so the reveal clips from the right — same as a scroll view at offset 0.
- `ClipRect` clips paint output to the `SizedBox` bounds.
- When `_revealWidth == _totalWidth` (max complexity), no overflow occurs and `ClipRect` is a no-op. Correct.
- When `complexity == 0`, `_revealWidth` = 12px (from `_minFigures = 0.6`). The narrow clip still works correctly.

No issues found.

## Call sites

- **`BreathSessionListCell.dart:58`** — `ComplexityIndicator(complexity: model.complexity)` — no `width`, takes the `Align(centerRight)` path. Unchanged, compatible.
- **`ConstructorFooter.dart:64`** — `ComplexityIndicator(complexity: state.complexity, width: 120)` — wraps in `SizedBox(width: 120)` + `Align(centerLeft)`. Unchanged, compatible.

Public API (`complexity`, `width`) is identical. No call-site changes needed.

## Imports

`SingleChildScrollView` and `NeverScrollableScrollPhysics` come from `material.dart`, which is still imported. No orphaned imports.

## Security / runtime risk

None. Pure stateless UI widget with no user input handling.

REVIEW_PASS
