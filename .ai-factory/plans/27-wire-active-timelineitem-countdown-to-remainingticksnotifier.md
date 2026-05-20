# Plan: Wire active `_TimelineItem` countdown to `remainingTicksNotifier`

## Context
Route the per-tick countdown in the active timeline row through the dedicated `remainingTicksNotifier` `ValueListenable<int>` exposed on `BreathViewModel`, so only the active `_TimelineItem`'s duration `Text` rebuilds at 1 Hz instead of the whole screen subtree. Inactive rows keep rendering `step.duration` from props. See `.ai-factory/notes/11-breath-session-tick-render-scope.md`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Widget API

- [x] **Task 1: Add `remainingTicksListenable` param to `BreathTimelineWidget`**
  Files: `packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart`
  Add a `final ValueListenable<int> remainingTicksListenable;` field to `BreathTimelineWidget` (import `package:flutter/foundation.dart` for `ValueListenable`). Make it `required` in the constructor. Thread the value into the active `_TimelineItem`: inside `_buildList`'s `itemBuilder`, when `isActive == true`, pass `remainingTicksListenable: widget.remainingTicksListenable` to `_TimelineItem`; otherwise pass `null`. No other display changes.

- [x] **Task 2: Consume listenable inside `_TimelineItem` for the duration `Text`** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart`
  Add `final ValueListenable<int>? remainingTicksListenable;` to `_TimelineItem` (nullable; populated only when `isActive`). In `build`, replace the `Text('${step.duration ?? 0}', style: textStyle)` node with conditional rendering: when `isActive && remainingTicksListenable != null`, wrap the duration `Text` in a `ValueListenableBuilder<int>(valueListenable: remainingTicksListenable!, builder: (_, ticks, __) => Text('$ticks', style: textStyle))`; otherwise keep the existing `Text('${step.duration ?? 0}', style: textStyle)`. Preserve existing `textStyle`, layout, and surrounding `Row`/`AnimatedScale`/`AnimatedOpacity` structure unchanged.

### Phase 2: Screen wiring

- [x] **Task 3: Pass `remainingTicksNotifier` from `BreathSessionScreen` to `BreathTimelineWidget`** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  In the `build` method (around line 215 where `BreathTimelineWidget` is instantiated), add `remainingTicksListenable: ref.read(breathViewModelProvider.notifier).remainingTicksNotifier` to the constructor call. Use `ref.read` (not `watch`) — the notifier reference is stable for the lifetime of the provider, and the `ValueListenableBuilder` handles per-tick rebuilds inside the active row only. No other change in this file.
