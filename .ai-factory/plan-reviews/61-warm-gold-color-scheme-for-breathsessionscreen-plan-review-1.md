# Plan Review: Warm gold color scheme for `BreathSessionScreen`

**Plan file:** `.ai-factory/plans/61-warm-gold-color-scheme-for-breathsessionscreen.md`
**Spec source:** `.ai-factory/notes/25-breath-session-gold-theme-controls.md` (Milestone A)
**Risk:** 🟢 Low — pure visual retheme, no state/logic changes, no migrations, no API surface change.

## Context Gates

- **Architecture**: WARN (informational). The plan stays within the existing layering — `mind_ui` exposes theme tokens, `breath_module` consumes them via `Theme.of(context)`. No new cross-package coupling or domain leakage. No module-system boundary changes. ✅
- **Rules** (`.ai-factory/RULES.md`): WARN (informational). Rules listed cover Module Service stateless contract, App.dart purity, constructor DI. None of them apply to a colour-only edit. ✅
- **Roadmap**: WARN. Did not verify a roadmap entry maps to "61-warm-gold-color-scheme…"; the plan filename suggests a milestone slot exists. Not blocking — work is well-scoped regardless.

## Verification against the codebase

All file paths, line targets, and literal colour values match the current source:

| Plan claim | Reality | OK |
|---|---|---|
| `_kWarmAccentDark = 0xFFF4BA40` in `AppTheme.dart` | line 36 — matches | ✓ |
| `_kWarmAccentLight = 0xFFF1A139` | line 37 — matches | ✓ |
| Both consumed via `tertiary:` in dark and light `ColorScheme` | lines 53 & 67 — matches | ✓ |
| `ControlButton.dart` uses `fromRGBO(0,217,255,0.2)` for `Material.color` | line 23 — matches | ✓ |
| `ControlButton.dart` non-destructive icon `0xFF00D9FF`, destructive `0xFFD90000` | line 31 — matches | ✓ |
| `BreathSessionScreen` Scaffold bg `0xFF0A0E27` | line 165 — matches | ✓ |
| `EclipseOrb.glowColor: 0xFF00C8E0`, `maskColor: 0xFF0A0E27` | lines 191–192 — matches | ✓ |
| `BreathShapeWidget.shapeColor: 0xFF00D9FF` | line 203 — matches | ✓ |
| Share & Edit `IconButton.color: 0xFF00D9FF` | lines 261, 276 — matches | ✓ |
| Star `IconButton`: currently `isStarred ? cs.tertiary : cs.primary` — plan simplifies both branches to `cs.tertiary` | lines 269–271 — matches | ✓ |
| `EclipseOrb` constructor default `glowColor = 0xFF00C8E0` | line 11 — matches | ✓ |

`_kAccent = 0xFF00D9FF` (cyan) is wired as `colorScheme.primary` in both themes, so the "central `ControlButton` stays cyan via `cs.primary`" design intent is preserved correctly by the plan.

## Findings

### Observations / minor gaps (non-blocking)

1. **`BreathTimelineWidget.dart:214` still hardcodes cyan for the active step indicator** — `isActive ? const Color(0xFF00D9FF) : Colors.white.withValues(alpha: 0.45)`. This widget renders directly on `BreathSessionScreen`, so after the retheme the timeline's "active step" dot remains cyan while the shape, orb, share/edit/star icons turn gold. This may be deliberate (visually pairs the timeline active marker with the still-cyan central ControlButton), but the plan does not mention it, nor does the source note. Recommend either:
   - Calling it out explicitly as "left cyan on purpose" in the plan (and matching design rationale to the central button), **or**
   - Adding a sub-task in Phase 3 to route this through `cs.primary` (to track the central button) or `cs.tertiary` (to track the bottom-bar icons).

2. **Dead-default cyan literals not covered by Phase 4 pattern.** Task 4 updates `EclipseOrb`'s default `glowColor` for consistency even though the call site always passes one. The same dead-default pattern exists in two places the plan does not touch:
   - `packages/breath_module/lib/src/BreathSession/Views/BreathShapeWidget.dart:46` — `shapeColor ?? const Color(0xFF00D9FF)`
   - `packages/breath_module/lib/src/BreathSession/Views/BreathShapePainter.dart:19` — `this.shapeColor = const Color(0xFF00D9FF)`
   These never render at runtime because `BreathSessionScreen` passes `shapeColor: cs.tertiary` (after Task 3). For consistency with Task 4's stated rationale ("keep the widget's standalone preview consistent with the new theme") consider also updating these defaults to `0xFFFFB347` — or explicitly note their omission.

3. **Minor — repeated `Theme.of(context)` lookups.** Phase 3 caches `final cs = Theme.of(context).colorScheme;` but then writes `Theme.of(context).scaffoldBackgroundColor` twice. Trivially cleaner to also cache `final theme = Theme.of(context);` and reuse, but the cost is negligible (Flutter's `Theme.of` is an `InheritedWidget` lookup, not expensive). Not blocking.

### Positive notes

- The plan correctly scopes to Milestone A and explicitly excludes Milestone B (mute / screen-off). No accidental scope creep.
- Dependency order (Task 1 first, then 2/3/4 depend on it) is correct: changing the constants without re-routing literals would not visually move the needle, and re-routing without changing constants would only swap one cyan-like for the current dull gold.
- The central `ControlButton` design intent (stay cyan via `cs.primary`, visually distinct from gold bottom-bar) is consistent with the existing theme wiring and is preserved.
- The star ternary simplification (both branches → `cs.tertiary`, rely on filled-vs-outline icon for state) is sound — accessibility-wise the iconography already carries the state signal.
- Single end-of-task commit is appropriate for a cohesive visual change. No staged migrations needed.
- No security, performance, or data-model concerns — read-only theme indirection.

## Recommendation

The plan is accurate, well-scoped, and matches the source spec. The findings above are all cosmetic consistency suggestions, not correctness bugs. Resolving finding #1 explicitly (decide: keep timeline active-step cyan, or theme it) would close the only visible gap; findings #2 and #3 are nice-to-haves.

PLAN_REVIEW_PASS
