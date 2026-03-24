# Review 2: Add RepaintBoundary around list cells

## Changes reviewed

After review-1 identified that all four manual `RepaintBoundary` wrappers were redundant (Flutter's `ListView.builder` and `SliverChildBuilderDelegate` already wrap each child via `addRepaintBoundaries: true` by default), the code changes were reverted.

Current diff contains only:
- `.ai-factory/plans/04-add-repaintboundary-around-list-cells.md` (new, staged)
- `.ai-factory/reviews/04-add-repaintboundary-around-list-cells-review-1.md` (new, staged)

No application code was changed.

## Verification

All four target files confirmed clean — no manual `RepaintBoundary` present, matching their pre-milestone state:

| File | Status |
|------|--------|
| `BreathSessionListScreen.dart` | Original — `return switch (item) { ... }` without wrapper |
| `BreathTimelineWidget.dart` | Original — `_buildSeparator` and `SizedBox` returned directly |
| `AutoScrollCarousel.dart` | Original — `Padding` returned directly |
| `HomeScreen.dart` | Original — `HomeScreenCell` returned directly |

## Conclusion

No code changes to review. The milestone's goal (repaint isolation per list cell) is already satisfied by the framework's default behavior. No action needed.

REVIEW_PASS
