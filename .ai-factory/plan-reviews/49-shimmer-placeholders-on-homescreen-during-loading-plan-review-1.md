# Plan Review: Shimmer placeholders on HomeScreen during loading

**Plan file:** `.ai-factory/plans/49-shimmer-placeholders-on-homescreen-during-loading.md`
**Note spec:** `.ai-factory/notes/20-home-shimmer-loading.md`

## Summary

**Risk Level:** 🟢 Low

The plan accurately reflects the spec note and the current source. The codebase facts it relies on (`shimmer: ^3.0.0` already in `pubspec.yaml`, `kCardCornerRadius` exported from `mind_ui`, `SuggestionsCard` already importing `mind_ui`, the structure of `HomeViewModel._loadSuggestions/_loadStats`, the event cases in `_onEvent`, and the absence of any test referencing `HomeState.isLoading`) all check out. Two minor issues worth flagging before implementation; neither is blocking.

## Context Gates

- **ARCHITECTURE.md** — not applicable; this is a presentation-only change within an existing module boundary. No DI, no new service, no notifier touched. ✅
- **RULES.md** — no explicit project rule violated. The plan correctly stays on the presentation side, uses DTOs already in `HomeState`, and does not push domain models into widgets. ✅
- **ROADMAP.md** — not checked for milestone linkage; this is an isolated UX polish. WARN (informational only).

## Verified codebase facts

- `lib/HomeModule/Presentation/HomeScreen/Models/HomeState.dart` has fields exactly as the plan describes (`suggestions, stats, isGuest, isLoading, error`).
- `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart` `_loadSuggestions` uses `isLoading` true→false in success/catch; `_loadStats` currently has no loading flag and skips writing `stats` when `null`. The plan's rewrite preserves both behaviours.
- `_onEvent` cases match exactly what the plan enumerates (`StatsInvalidated`, `HomeSessionExpired`, `HomeAuthenticated`, `HomeAppResumed`, `HomeGrpcReconnected`).
- `SuggestionsCard.dart` already imports `package:mind_ui/mind_ui.dart`, so `kCardCornerRadius` is in scope as the plan claims.
- `StatsCard.dart` does NOT import `mind_ui`. The plan does not require it to — `_StatsShimmer` does not use `kCardCornerRadius`. ✅
- `shimmer: ^3.0.0` is on line 67 of `pubspec.yaml`. ✅
- No test file (`test/`) references `HomeState`, `isLoading`, or `HomeViewModel`. The rename is safe — no test fixtures break.
- Grep confirms the only `isLoading` references in the home module are the five lines the plan rewrites.

## Issues

### 1. `const` constructor not explicitly required (minor)

The plan writes `return const _SuggestionsShimmer();` and `return const _StatsShimmer();`. For these to compile as `const`, each private class needs an explicit `const _SuggestionsShimmer();` / `const _StatsShimmer();` constructor. The note spec at `.ai-factory/notes/20-home-shimmer-loading.md` does not declare const constructors in its code samples — an implementer copying the note verbatim and the `const` invocations from the plan together will hit a compile error.

**Recommendation:** Add a sentence to both Task 3 and Task 4: "Declare `const _SuggestionsShimmer();` / `const _StatsShimmer();` constructor so the call site can use `const`." Alternatively drop the `const` at the call sites — both classes contain no fields, so the perf delta is negligible.

### 2. Microtask delay leaves a one-frame "no-shimmer" gap (informational)

`HomeViewModel.build()` returns `HomeState.initial().copyWith(isGuest: …)` synchronously, then schedules `_loadInitialData()` via `Future.microtask`. So on first build for an authenticated user, the very first frame still has `isSuggestionsLoading == false` and `isStatsLoading == false`, producing one frame of empty `SizedBox.shrink()` before the shimmer appears.

This mirrors the existing behaviour with `CircularProgressIndicator`, so it's not a regression — but the plan's stated goal is "no jarring layout shift" and this is the one remaining micro-flicker. Pre-seeding `isSuggestionsLoading: true, isStatsLoading: true` in `build()` for non-guest users would eliminate it cleanly.

**Recommendation (optional):** Consider amending Task 2 with:
```dart
return HomeState.initial().copyWith(
  isGuest: service.isGuest,
  isSuggestionsLoading: !service.isGuest,
  isStatsLoading: !service.isGuest,
);
```
Not blocking — the existing behaviour is acceptable and matches what shipped before.

## Positive notes

- Plan correctly preserves the guest behaviour (`!state.isGuest` guard on both shimmers); guests still see `SizedBox.shrink()` and no shimmer flicker on app start.
- Split into two flags (`isSuggestionsLoading` / `isStatsLoading`) is the right granularity — the two cards reload independently (`HomeAppResumed` reloads only suggestions; `StatsInvalidated` reloads only stats), so a single flag would either over-shimmer or miss states.
- Geometry of the shimmer (margins, padding, heights, divider hairline) matches the real card's outer chrome exactly, so the swap is layout-stable once data arrives.
- Commit plan is sensibly split (state/VM first, then widgets) — each commit compiles independently because `SuggestionsCard` and `StatsCard` only read state fields that exist after commit 1.
- Reuse of `theme.colorScheme.surfaceContainerHighest` / `surface` keeps the shimmer themable in both light and dark mode without hardcoded colors.

PLAN_REVIEW_PASS
