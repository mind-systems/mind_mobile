# Plan: Remove the dead cyan default `shapeColor` fallbacks

## Context
Drop the unreachable cyan `shapeColor` defaults in `BreathShapeWidget` and `BreathShapePainter`, making the parameter required since the single call site already passes `cs.tertiary` — no behavior change.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Remove dead defaults

- [x] **Task 1: Require `shapeColor` in `BreathShapePainter`**
  Files: `packages/breath_module/lib/src/BreathSession/Views/BreathShapePainter.dart`
  Change the field from `final Color shapeColor;` (currently defaulted in the constructor) so the constructor no longer assigns a default. In the constructor parameter list, replace `this.shapeColor = const Color(0xFF00D9FF),` with `required this.shapeColor,`. Leave `pointColor`, `shapeStrokeWidth`, and `pointRadius` defaults untouched — the spec only targets `shapeColor`.

- [x] **Task 2: Require `shapeColor` in `BreathShapeWidget` and drop the fallback** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/Views/BreathShapeWidget.dart`
  Change the field declaration from `final Color? shapeColor;` to `final Color shapeColor;`. In the constructor, replace `this.shapeColor,` with `required this.shapeColor,`. In `build`, change the `BreathShapePainter(...)` call from `shapeColor: shapeColor ?? const Color(0xFF00D9FF),` to `shapeColor: shapeColor,`. Leave the other nullable params (`pointColor`, `strokeWidth`, `pointRadius`) and their `??` fallbacks unchanged.

Note: the single call site `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart:242` already passes `shapeColor: cs.tertiary`, so it satisfies the new required parameter without edits. After the changes, run `flutter analyze` (full path `/usr/local/bin/flutter`) inside `packages/breath_module` to confirm no analyzer errors.
