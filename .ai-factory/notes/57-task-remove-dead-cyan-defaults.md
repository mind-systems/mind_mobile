# Task Spec — Remove the dead cyan default `shapeColor` fallbacks

**Date:** 2026-05-31
**Roadmap:** ROADMAP.md Phase 26
**Provenance:** note 44 B1 (note 36 Area B)

## Current state
`packages/breath_module/lib/src/BreathSession/Views/BreathShapeWidget.dart:46` and `BreathShapePainter.dart:19` both default `shapeColor` to `const Color(0xFF00D9FF)`, always overridden by `cs.tertiary` from `BreathSessionScreen.dart:242` — an unreachable, misleading fallback left over from the pre-Phase-20 cyan scheme. (Verified: single call site — `BreathShapeWidget(` appears once at `BreathSessionScreen.dart:239`; `BreathShapePainter(` once inside the widget.)

## Target
- In `BreathShapeWidget` drop `?? const Color(0xFF00D9FF)` and make `shapeColor` a required parameter.
- In `BreathShapePainter` remove the default and require it in the constructor (the painter has no `BuildContext`; the widget supplies the value).

## Guards
- The single call site already passes `cs.tertiary`, so no behavior change.

## Files
- `packages/breath_module/lib/src/BreathSession/Views/BreathShapeWidget.dart`
- `packages/breath_module/lib/src/BreathSession/Views/BreathShapePainter.dart`
