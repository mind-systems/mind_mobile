# Code Review: Fix invisible shimmer colors on HomeScreen

**Branch:** dev
**Reviewed:** 2026-06-04
**Scope:** `StatsCard.dart`, `SuggestionsCard.dart` (plan/JSON artifacts excluded from code review)

## Summary

Two-file, two-line-each change replacing the un-themed `colorScheme.surfaceContainerHighest` / `colorScheme.surface` shimmer colors with the explicitly-defined `theme.cardColor` / `theme.highlightColor`. The change matches the plan and spec exactly.

## Verification

- **`SuggestionsCard.dart:73-74`** — `base = theme.cardColor`, `highlight = theme.highlightColor`. `base` flows into `Shimmer.fromColors(baseColor: base)` and every placeholder `Container(color: base)`; `highlight` is the sweep color. Correct.
- **`StatsCard.dart:66-67`** — identical replacement; `base` feeds `Shimmer.fromColors(baseColor: base)` and `_shimmerLine(base, ...)`. Correct.
- **`AppTheme.dart`** — confirmed both `cardColor` (`_kCardDark` / `_kCardLight`) and `highlightColor` (`_kShimmerHighlightDark` / `_kShimmerHighlightLight`) are set for both dark and light `ThemeData`. No auto-generation fallback risk — both resolve to defined, contrasting values.
- No structural changes; widget trees, imports, and call sites are untouched. `Theme.of(context)` was already obtained, so no new lookups. No null-safety, type, or runtime concerns. Light/dark both covered.

## Findings

None.

REVIEW_PASS
