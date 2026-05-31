# Task Spec — Make the active timeline row use the gold theme accent

**Date:** 2026-05-31
**Roadmap:** ROADMAP.md Phase 26
**Provenance:** note 44 Q3 (note 36 Area B)

## Current state
`packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart` `_TimelineItem.build` (~line 214) hardcodes `const Color(0xFF00D9FF)` (cyan) for the active row, inconsistent with the Phase 20 gold redesign (orb/shape/bottom-bar icons all read `cs.tertiary`).

## Decision (note 44 Q3)
The active row is breath-progress feedback, part of the redesigned session → **gold**. Cyan stays only on the central `ControlButton` (the interaction affordance).

## Target
Replace the literal with `Theme.of(context).colorScheme.tertiary` (`_TimelineItem` has a `BuildContext` in `build`).

## Files
- `packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart` (one file).
