# Code Review: Remove `MediaQuery.of(context)` from list cells

**Plan:** `02-remove-mediaquery-of-context-from-list-cells.md`
**Files changed:** 2
**Risk Level:** Low

## Changes reviewed

### `BreathSessionListCell.dart` (line 18)
`MediaQuery.of(context).devicePixelRatio` → `MediaQuery.devicePixelRatioOf(context)`

### `BreathSessionListSkeletonCell.dart` (line 25)
`MediaQuery.of(context).devicePixelRatio` → `MediaQuery.devicePixelRatioOf(context)`

## Correctness

- Both files use `pixel` only for hairline divider height — semantics are unchanged.
- `MediaQuery.devicePixelRatioOf(context)` returns the same `double` value as the old accessor. The only difference is the InheritedWidget dependency scope: it subscribes to `devicePixelRatio` changes only, not the full `MediaQueryData`.
- No other `MediaQuery.of(context)` calls exist in either file — no remaining broad subscriptions.
- Both files already import `package:flutter/material.dart`, which exports `MediaQuery`. No import changes needed — none were made.
- Both widgets are `StatelessWidget` — no lifecycle or state concerns.

## Issues

None found.

## Notes

- Clean, minimal change. Exactly what the plan specified, nothing more.
- Both tasks marked complete in the plan file.

REVIEW_PASS
