# Plan Review: Pin BreathSessionScreen to the dark palette via named `AppColors`, keep only the orb gold

**Plan:** `100-pin-breathsessionscreen-to-the-dark-palette-via-named-appcolors-keep-only-the-orb-gold.md`
**Review round:** 1
**Risk Level:** 🟢 Low

## Verdict
The plan is accurate, internally consistent, and matches the codebase exactly. Every file path, line number, and symbol referenced was verified. No missing steps, no wrong assumptions, no architectural issues. UI-only change — no migrations, no security surface.

## Verification against the codebase

### Task 1 — `AppColors` holder in `mind_ui`
- Private constants exist with the exact values the plan cites: `_kBackgroundDark = 0xFF0A0E27` (line 6), `_kAccent = 0xFF00D9FF` (line 31), `_kWarmAccentDark = 0xFFFFB347` (line 36), `_kWarmAccentLight = 0xFFFF9D3D` (line 37). ✅
- `AppTheme.dart` is exported by the barrel `packages/mind_ui/lib/mind_ui.dart` (line 1: `export 'src/AppTheme.dart';`), so the new public `AppColors` is re-exported automatically with no barrel edit. ✅
- No existing `AppColors` symbol anywhere in the codebase — no naming collision. ✅
- The change is purely additive; it does not touch `AppTheme.dark()` / `AppTheme.light()` or any token values. ✅

### Task 2 — Repaint `BreathSessionScreen`
All cited line numbers match the current file exactly:
- Line 178: `final cs = Theme.of(context).colorScheme;` — to be removed. ✅
- Line 184: `backgroundColor: Theme.of(context).scaffoldBackgroundColor` → `AppColors.backgroundDark`. ✅
- Line 220: `glowColor: cs.tertiary` → `AppColors.warmAccentDark`. ✅
- Lines 221–224: `maskColor: Theme.of(context).scaffoldBackgroundColor` → `AppColors.backgroundDark`. ✅
- Line 242: `shapeColor: cs.tertiary` → `AppColors.accent`. ✅
- Line 329: mute unmuted color `cs.tertiary` → `AppColors.accent`; muted branch at line 328 (`Colors.white.withValues(alpha: 0.3)`) correctly left untouched. ✅
- Line 350: share `cs.tertiary` → `AppColors.accent`. ✅
- Line 358: star `cs.tertiary` → `isStarred ? AppColors.warmAccentDark : AppColors.accent`. ✅
- Line 363: edit `cs.tertiary` → `AppColors.accent`. ✅
- Lines 339–343: heart/favorite `IconButton` correctly identified as untouched (`isActive ? Colors.red : white α0.3`). ✅
- `cs.tertiary` appears on exactly these lines — after the listed swaps there are no remaining `cs.` references, so removing the `final cs` line on its own leaves no unused-variable warning and no dangling reference. ✅
- The screen already imports `package:mind_ui/mind_ui.dart` (line 5), so `AppColors` resolves with no new import. ✅

### Root-cause diagnosis is correct
`EclipseOrb` draws the glow ring with `glowColor` and then paints a central filled disk with `maskColor` over it (`EclipseOrb.dart` lines 232–238). Binding `maskColor` to the active theme's `scaffoldBackgroundColor` means that under the light theme the central disk is painted near-white (`0xFFF0F4FC`) — precisely the "white orb" symptom. Pinning `maskColor` to `AppColors.backgroundDark` (`0xFF0A0E27`) restores the dark center. The plan's diagnosis ("the white orb was the `maskColor`/background binding bug, not a gold-value problem") is verified correct.

### Task 3 — Analyzer verification
Running `flutter analyze` in both `packages/mind_ui` and `packages/breath_module` is the right gate. The full Flutter path (`/usr/local/bin/flutter`) matches project memory. ✅

## Context Gates
- **Architecture (`.ai-factory/ARCHITECTURE.md` present):** No boundary violation. `AppColors` lives in `packages/mind_ui`, the shared UI package that already owns theme tokens; `breath_module` already depends on it. Consistent with the module system. **PASS**
- **Rules (`.ai-factory/RULES.md` present):** The three rules concern Module Service statelessness, App.dart purity, and constructor injection — none apply to a UI color change. **PASS**
- **Roadmap:** This is a `fix` (revert of over-applied gold theme from `fc23442`, tracked alongside note `83-revert-breath-screen-gold-theme-leak.md`). Roadmap linkage is present in the surrounding milestone numbering. **WARN (non-blocking)** — no explicit ROADMAP task ID is cited in the plan header, but the work is clearly scoped and traceable.

## Observations (non-blocking)
- **Intentional theme non-responsiveness.** Pinning the screen to fixed dark constants means it stays dark even when the light theme is active. The plan's Context section states this is the explicit goal ("pins the screen to fixed dark-palette constants"), so this is by design, not a defect. Worth keeping in mind if a light-mode variant of the session screen is ever desired.
- **Guards are well-specified.** The "do NOT touch" list correctly fences off the sound/mute opacity, the heartbeat favorite button, the gold token values, `ControlButton.dart`, and `EclipseOrb.dart` — all confirmed as elements that should not change.

## Positive Notes
- Exceptionally precise: every line number and color value was independently confirmed against the source.
- Single source of truth preserved — `AppColors` mirrors the existing private constants rather than duplicating raw hex into the screen.
- Correct, evidence-based root-cause analysis distinguishing the `maskColor` binding bug from the gold-value (which was never wrong).
- Clear dependency ordering (Task 2 depends on Task 1; Task 3 verifies).

PLAN_REVIEW_PASS
