# Plan Review: Make the active timeline row use the gold theme accent

**Plan:** `101-make-the-active-timeline-row-use-the-gold-theme-accent.md`
**Files Reviewed:** 1 plan + 2 source files (`BreathTimelineWidget.dart`, `AppTheme.dart`)
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** WARN — no violation. The change is confined to a presentation widget inside `packages/breath_module`, touching only a local color literal. No module-boundary, DI, or domain-leak implications.
- **Rules (`.ai-factory/RULES.md`):** No violation surfaced by this plan. Using `Theme.of(context).colorScheme.tertiary` instead of a hardcoded color is consistent with the surrounding theming convention.
- **Roadmap (`.ai-factory/ROADMAP.md`):** WARN — the plan does not cite a milestone/roadmap linkage. This is a small cosmetic follow-up to the Phase 20 gold redesign; consider noting the roadmap anchor, but not blocking.
- **Skill-context (`.ai-factory/skill-context/aif-review/SKILL.md`):** Not present (directory empty) — no project-specific overrides to apply.

## Verification of Plan Assumptions

All claims in the plan were checked against the codebase and hold:

1. **Hardcoded cyan location** — confirmed. `BreathTimelineWidget.dart:213-214`:
   ```dart
   final color =
   isActive ? const Color(0xFF00D9FF) : Colors.white.withValues(alpha: 0.45);
   ```
2. **`build` receives `BuildContext context`** — confirmed (`_TimelineItem.build`, line 210), so `Theme.of(context).colorScheme` is reachable with no signature change.
3. **`cs.tertiary` is the gold accent** — confirmed in `AppTheme.dart`: `tertiary: _kWarmAccentDark` = `0xFFFFB347` (warm amber-gold), `_kWarmAccentLight` = `0xFFFF9D3D`. The doc comment explicitly designates `colorScheme.tertiary` as the gold accent.
4. **Gold is the established accent on this screen** — confirmed. `BreathSessionScreen.dart` already uses `cs.tertiary` for glow, shape, and text colors (lines 220, 242, 329, 350, 358, 363), so the timeline row will now match.
5. **Cyan stays on the ControlButton** — confirmed. `0xFF00D9FF` is `_kAccent` = `colorScheme.primary`, a separate token from `tertiary`. The plan correctly scopes the edit to the timeline color literal and does not touch the interaction affordance.
6. **File path** — correct and exact.

## Critical Issues

None.

## Minor Notes (non-blocking)

- The light theme will render the active row in `_kWarmAccentLight` (`0xFFFF9D3D`) rather than amber — this is the intended theme-aware behavior and an improvement over the theme-blind hardcoded cyan, so no action needed. Worth being aware of if the screen is ever expected to look identical across brightness modes.
- Settings declare Testing: no / Docs: no. Appropriate for a one-line, theme-token color swap with no behavioral change.

## Positive Notes

- Replaces a magic color literal with a semantic theme token — eliminates one source of theme drift.
- Edit is minimal, well-scoped, and reads the color scheme once at the top of `build` as recommended.
- Plan explicitly calls out what *not* to touch (ControlButton cyan, inactive branch, animation/text logic), reducing the chance of scope creep.

PLAN_REVIEW_PASS
