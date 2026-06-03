# Plan Review: Fix invisible shimmer colors on HomeScreen

**Plan:** `04-fix-invisible-shimmer-colors-on-homescreen.md`
**Risk Level:** 🟢 Low

## Verification Against Codebase

I verified every factual claim in the plan against the actual source.

### Root-cause diagnosis — confirmed correct
`packages/mind_ui/lib/src/AppTheme.dart` proves the diagnosis exactly:
- `cardColor` (`_kCardDark`/`_kCardLight`) and `highlightColor` (`_kShimmerHighlightDark`/`_kShimmerHighlightLight`) **are** explicitly set in both `dark()` and `light()` themes.
- `colorScheme.surfaceContainerHighest` is **never** set, so Flutter auto-derives it from the seed — near-identical to the background.
- `colorScheme.surface` is set to `_kBackgroundDark`/`_kBackgroundLight` — i.e. literally the scaffold background. The current shimmer uses `surface` as its highlight, so the highlight equals the background → invisible sweep. The plan's claim is precise, not approximate.

### File paths & line numbers — accurate
- `lib/HomeModule/Presentation/HomeScreen/Widgets/SuggestionsCard.dart` — `_SuggestionsShimmer.build()` lines 73-74 hold exactly:
  `final base = theme.colorScheme.surfaceContainerHighest;` / `final highlight = theme.colorScheme.surface;`
- `lib/HomeModule/Presentation/HomeScreen/Widgets/StatsCard.dart` — `_StatsShimmer.build()` lines 66-67 hold the identical two lines.
- Both `base` and `highlight` are local `final`s consumed only within their own `build()`; `base` is reused for the placeholder block fills and `highlight` only by `Shimmer.fromColors`. Swapping the source colors is self-contained — no downstream references break.

### Reference pattern — valid
`packages/breath_module/lib/src/BreathSessionListSkeletonCell.dart` does use `theme.cardColor` as base and `theme.highlightColor` as the shimmer highlight (lines 24, 64-66). The plan correctly mirrors an existing, working convention rather than inventing one.

## Context Gates
- **Architecture (`ARCHITECTURE.md`):** Pass. Pure presentation-layer color swap inside `lib/HomeModule/Presentation/...`; no boundary, DI, or layering impact.
- **Rules (`RULES.md`):** Pass. No new dependencies, no `pubspec.yaml` edits, no domain leakage.
- **Roadmap (`ROADMAP.md`):** WARN — the plan does not reference a roadmap milestone. This is a small cosmetic bug fix, so missing linkage is non-blocking, but worth noting for traceability.

## Observations (non-blocking)
- The `Settings` block lists `Logging: minimal`. A two-line color swap warrants no logging at all; "minimal" effectively means none here. No action needed.
- After the change, both shimmers will use `cardColor` for the placeholder block fills (`base`) — visually consistent with `SuggestionCarouselItem` (line 32, already `theme.cardColor`) and the breath skeleton. Good consistency outcome.
- No test/codegen/migration implications (`Testing: no`, no schema touch) — correct call for a theme-token fix.

## Conclusion
The plan is accurate, minimal, self-contained, and follows an existing in-repo convention. Both target locations and line numbers match the current source, and the root-cause analysis is provably correct from `AppTheme`. No missing steps, no wrong assumptions, no architectural concerns.

PLAN_REVIEW_PASS
