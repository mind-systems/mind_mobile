# Mind Mobile — Roadmap

## Milestones

### Scroll Performance Fix (60fps)

- [x] **Throttle `_onScroll`** — add debounce/throttle so `loadNextPage()` is not called on every scroll pixel
- [ ] **Remove `MediaQuery.of(context)` from list cells** — replace with `View.of(context).devicePixelRatio` in `BreathSessionListCell` and `BreathSessionListSkeletonCell` to avoid unnecessary InheritedWidget subscriptions
- [ ] **Refactor `ComplexityIndicator`** — remove the inner `SingleChildScrollView` (redundant Scrollable per cell), replace with `ClipRect` + `OverflowBox`; see [notes/01-complexity-indicator-clip.md](.ai-factory/notes/01-complexity-indicator-clip.md)
- [ ] **Add `RepaintBoundary` around list cells** — isolate repaint per cell so updating one cell does not trigger repaints in its neighbors

## Completed

| Milestone | Date |
|-----------|------|
