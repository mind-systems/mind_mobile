# Plan: Add RepaintBoundary around list cells

## Context
Wrap every cell returned by `ListView.builder` / `SliverChildBuilderDelegate` item builders in a `RepaintBoundary` so that updating one cell (state change, animation tick) does not dirty its neighbors. The project currently has zero `RepaintBoundary` usages.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Dynamic list builders

- [x] **Task 1: BreathSessionListScreen cells**
  Files: `packages/breath_module/lib/src/BreathSessionsList/BreathSessionListScreen.dart`
  In `_buildBody`, the `itemBuilder` returns one of three widgets via a `switch` expression. Wrap the entire `return switch (item) { ... }` result in a `RepaintBoundary`. This isolates every cell (session cell, section header, skeleton shimmer) from its neighbors. The skeleton cells contain `Shimmer.fromColors` animation, so isolation is especially valuable here.

- [x] **Task 2: BreathTimelineWidget items**
  Files: `packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart`
  In `_buildList`, the `itemBuilder` returns either a separator or a `SizedBox` containing `_TimelineItem` (which uses `AnimatedScale` + `AnimatedOpacity`). Wrap both return paths in `RepaintBoundary`. For the `SizedBox` branch, wrap the outer `SizedBox` (preserving the `key` on it). For the separator branch, wrap the `_buildSeparator` result.

- [x] **Task 3: AutoScrollCarousel items**
  Files: `lib/HomeModule/Presentation/HomeScreen/Widgets/AutoScrollCarousel.dart`
  In `build`, the `itemBuilder` returns a `Padding` wrapping the caller's widget. Wrap the `Padding` in a `RepaintBoundary`. This is ticker-driven (continuous `jumpTo` on every frame), so isolating each item prevents full-list repaints during auto-scroll.

- [x] **Task 4: HomeScreen grid cells**
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeScreen.dart`
  In the `SliverChildBuilderDelegate` callback, wrap `HomeScreenCell(item: modules[index])` in a `RepaintBoundary`. The grid only has 3 items so the perf gain is minor, but it keeps the pattern consistent across all item builders.
