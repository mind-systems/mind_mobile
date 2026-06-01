# Code Review — Make the active timeline row use the gold theme accent

**Plan:** `.ai-factory/plans/101-make-the-active-timeline-row-use-the-gold-theme-accent.md`
**Reviewed file:** `packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart`

## Scope of changes
Single, focused diff in `_TimelineItem.build`:
- Added `final cs = Theme.of(context).colorScheme;` at the top of `build`.
- Active-row color changed from hardcoded `const Color(0xFF00D9FF)` (cyan) to `cs.tertiary`.
- Inactive branch (`Colors.white.withValues(alpha: 0.45)`) and all animation/text logic left unchanged.

## Correctness verification
- **`cs.tertiary` is gold.** In `packages/mind_ui/lib/src/AppTheme.dart`, `tertiary` maps to `_kWarmAccentDark` (`0xFFFFB347`) and `_kWarmAccentLight` (`0xFFFF9D3D`) — the warm amber-gold accent. Matches the Phase 20 redesign intent.
- **Cyan affordance preserved.** The old literal `0xFF00D9FF` is the theme `primary` (`_kAccent`), which remains on the central `ControlButton`. This change does not touch it.
- **Consistent with existing usage.** `cs.tertiary` is already used throughout `BreathSessionScreen.dart` (orb glow, shape, bottom-bar icons), so this aligns the timeline with the established pattern.
- **Context availability.** `_TimelineItem` is a `StatelessWidget`; `build` receives a valid `BuildContext` mounted under the app's `MaterialApp`/theme, so `Theme.of(context)` resolves correctly. The `const` was correctly dropped since `cs.tertiary` is non-const.

## Runtime / regression checks
- No type mismatches: `cs.tertiary` is a `Color`, assignable to the same `color` variable used by `TextStyle`.
- No migrations, async, or state involved — purely a presentation constant swap.
- No analyzer concern: removing `const` from the ternary is required and correct; the line is now non-const, which is valid.
- The inactive-row hardcoded white is intentionally retained per the spec (only the active row was in scope).

## Findings
None. The change is minimal, correct, and matches the plan exactly.

REVIEW_PASS
