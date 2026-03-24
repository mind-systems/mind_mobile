# Review: Add RepaintBoundary around list cells

## Critical: All four changes are redundant

`ListView.builder` and `SliverChildBuilderDelegate` already wrap every child in a `RepaintBoundary` by default. This is controlled by the `addRepaintBoundaries` parameter, which defaults to `true`.

From the Flutter SDK (`scroll_delegate.dart:556–561`):
```dart
if (addRepaintBoundaries) {
  child = RepaintBoundary(child: child);
}
```

This applies to all four changed files:

| File | List widget | Already wrapped? |
|------|-------------|------------------|
| `BreathSessionListScreen.dart` | `ListView.builder` | Yes — delegates to `SliverChildBuilderDelegate(addRepaintBoundaries: true)` |
| `BreathTimelineWidget.dart` | `ListView.builder` | Yes — same |
| `AutoScrollCarousel.dart` | `ListView.builder` | Yes — same |
| `HomeScreen.dart` | `SliverChildBuilderDelegate` directly | Yes — `addRepaintBoundaries: true` by default |

Every item returned by `itemBuilder` is already wrapped in a `RepaintBoundary` before it enters the render tree. The manual `RepaintBoundary` wrapping creates a second, redundant layer per item.

### Impact

- **No bugs** — double `RepaintBoundary` doesn't cause visual or functional issues.
- **Slight overhead** — each item now has two `RenderRepaintBoundary` nodes in the render tree instead of one. The extra layer allocation, compositing, and memory are minor but pointless.
- **Misleading code** — the explicit wrapping implies the framework doesn't do this, which could confuse future readers.

### Recommendation

Remove all four manual `RepaintBoundary` wrappers. The stated goal ("isolate repaint per cell so updating one cell does not trigger repaints in its neighbors") is already achieved by Flutter's default behavior. No code changes are needed for this milestone.

If the intent is to document that repaint isolation matters here, a code comment on the `itemBuilder` would be clearer than a redundant widget.

REVIEW_FAIL
