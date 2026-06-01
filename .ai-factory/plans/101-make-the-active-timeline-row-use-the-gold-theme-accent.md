# Plan: Make the active timeline row use the gold theme accent

## Context
The active breath-timeline row hardcodes cyan `0xFF00D9FF`, inconsistent with the Phase 20 gold redesign. This milestone switches the active row to the theme's gold accent (`cs.tertiary`), leaving cyan only on the central interaction `ControlButton`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Recolor active timeline row

- [x] **Task 1: Replace hardcoded cyan with `cs.tertiary`**
  Files: `packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart`
  In `_TimelineItem.build` (~line 213), the active-row color is `const Color(0xFF00D9FF)`. The `build` method already receives `BuildContext context`. Read the color scheme once at the top of `build` (e.g. `final cs = Theme.of(context).colorScheme;`) and change the active branch to use `cs.tertiary`:
  ```dart
  final color =
      isActive ? cs.tertiary : Colors.white.withValues(alpha: 0.45);
  ```
  Keep the inactive branch (`Colors.white.withValues(alpha: 0.45)`) and all surrounding animation/text logic unchanged. Do not touch the `ControlButton` cyan elsewhere — cyan intentionally remains on the interaction affordance.
