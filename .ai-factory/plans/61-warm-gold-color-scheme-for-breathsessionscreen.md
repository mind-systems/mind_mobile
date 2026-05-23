# Plan: Warm gold color scheme for `BreathSessionScreen`

## Context
Replace the hardcoded cyan palette on the breath session screen with the warm amber-gold `colorScheme.tertiary` so the session matches the UAE-ambiance theme direction. The theme already exposes `tertiary`; this milestone tunes its two underlying constants and routes every cyan literal on the session screen (and its `ControlButton` consumer) through the theme. The central pause/play/restart `ControlButton` remains cyan via `cs.primary` and is intentionally kept distinct from the bottom-bar controls.

Full spec: `.ai-factory/notes/25-breath-session-gold-theme-controls.md` (Milestone A only — Milestone B mute + screen-off is out of scope).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Theme constants

- [x] **Task 1: Update warm accent constants in `AppTheme.dart`**
  Files: `packages/mind_ui/lib/src/AppTheme.dart`
  Change the two top-level color constants used by `colorScheme.tertiary`:
  - `_kWarmAccentDark`: `Color(0xFFF4BA40)` → `Color(0xFFFFB347)` (warmer amber-gold, UAE ambient)
  - `_kWarmAccentLight`: `Color(0xFFF1A139)` → `Color(0xFFFF9D3D)` (slightly deeper for light background)
  Keep the comments accurate (warm amber-gold). Do not add any new theme fields or `ColorScheme` slots — both dark and light themes already consume these via `tertiary:`.

### Phase 2: Theme-driven control colors

- [x] **Task 2: Theme-driven colors in `ControlButton`** (depends on Task 1)
  Files: `packages/mind_ui/lib/src/ControlButton.dart`
  Read `final cs = Theme.of(context).colorScheme;` once at the top of `build()` and replace the two hardcoded cyan literals:
  - `Material.color`: `const Color.fromRGBO(0, 217, 255, 0.2)` → `cs.primary.withValues(alpha: 0.2)`
  - `Icon.color` (non-destructive branch): `const Color(0xFF00D9FF)` → `cs.primary`
  The destructive branch keeps `const Color(0xFFD90000)` (do not theme it in this milestone). The central pause/play/restart button uses `cs.primary` deliberately so it stays cyan and visually distinct from the gold bottom-bar icons. No other behavior or layout changes.

### Phase 3: BreathSessionScreen retheme

- [x] **Task 3: Replace hardcoded cyan on `BreathSessionScreen`** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  In `build()`, read `final cs = Theme.of(context).colorScheme;` once near the top (after `layout` is computed, before the `return Scaffold(...)`). Replace every hardcoded color literal on this screen:
  - `Scaffold.backgroundColor`: `const Color(0xFF0A0E27)` → `Theme.of(context).scaffoldBackgroundColor`
  - `EclipseOrb.glowColor`: `const Color(0xFF00C8E0)` → `cs.tertiary`
  - `EclipseOrb.maskColor`: `const Color(0xFF0A0E27)` → `Theme.of(context).scaffoldBackgroundColor`
  - `BreathShapeWidget.shapeColor`: `const Color(0xFF00D9FF)` → `cs.tertiary`
  - Share `IconButton.color`: `const Color(0xFF00D9FF)` → `cs.tertiary`
  - Edit `IconButton.color`: `const Color(0xFF00D9FF)` → `cs.tertiary`
  - Star `IconButton.color`: simplify the ternary so both starred and unstarred branches use `cs.tertiary` (the fill vs outline icon already communicates state).
  Do not change `pointColor: Colors.white` or any non-cyan values. Do not touch the `ControlButton` invocations — Task 2 already routes them through the theme.

### Phase 4: EclipseOrb default

- [x] **Task 4: Update `EclipseOrb` default `glowColor`** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/Views/EclipseOrb.dart`
  Update the constructor default parameter `this.glowColor = const Color(0xFF00C8E0)` → `this.glowColor = const Color(0xFFFFB347)`. Cosmetic only — the call site in `BreathSessionScreen` always passes `cs.tertiary` after Task 3, so this default just keeps the widget's standalone preview consistent with the new theme.

## Commit Plan
- Single commit at the end (4 small tasks, all part of one cohesive retheme): "Switch BreathSessionScreen to warm gold colorScheme.tertiary"

<!-- orchestrator-sessions
planner: cea974b9-7060-4a5e-9d7c-692c229c63d5
implementer: 05534f72-a0ee-40b0-8cc5-e42bcdfb0144
-->
