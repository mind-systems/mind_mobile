# Code Review: Shimmer placeholders on HomeScreen during loading

**Plan:** `.ai-factory/plans/49-shimmer-placeholders-on-homescreen-during-loading.md`
**Files reviewed:**
- `lib/HomeModule/Presentation/HomeScreen/Models/HomeState.dart`
- `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`
- `lib/HomeModule/Presentation/HomeScreen/Widgets/SuggestionsCard.dart`
- `lib/HomeModule/Presentation/HomeScreen/Widgets/StatsCard.dart`

## Summary

Risk: 🟢 Low. The implementation matches the plan and the spec note. State, ViewModel, and widget changes are coherent. No security issues. No reference to the old `isLoading` field remains anywhere in the module. Both shimmer widgets compile as `const` (private `const` constructors declared). Runtime behaviour is correct in the happy path and on each `HomeEvent` case.

## Verification

- `Grep` for `isLoading` in `lib/HomeModule/` returns no hits — all references migrated cleanly to `isSuggestionsLoading` / `isStatsLoading`.
- `shimmer: ^3.0.0` is present in `pubspec.yaml` (line 67); no dependency drift.
- `kCardCornerRadius` is in scope in `SuggestionsCard` via `package:mind_ui/mind_ui.dart` (line 9). `StatsCard` does not need it.
- `_SuggestionsShimmer` and `_StatsShimmer` each declare `const _Xxx();` so `const _Xxx()` call sites compile.
- Concurrency: `_loadInitialData()` calls `_loadSuggestions()` then `_loadStats()` without `await`, but the first synchronous statement in each is `state = state.copyWith(isXxxLoading: true)`, so both flags become `true` before either await suspends. No flag-overwrite race.
- `HomeAuthenticated` first sets `isGuest: false` synchronously, then triggers `_loadInitialData()`; by the time the next frame renders, both shimmer guards (`!state.isGuest && state.isXxxLoading`) are true. Correct.
- `HomeSessionExpired` resets to `HomeState.initial()` which sets `isGuest: true` and clears both loading flags, so a logged-out user sees nothing. Correct.

## Findings

### 1. First-frame flicker on initial mount (informational, pre-existing)

`HomeViewModel.build()` returns `HomeState.initial().copyWith(isGuest: …)` synchronously with both loading flags `false`, and schedules `_loadInitialData()` via `Future.microtask`. For an authenticated user there is therefore one frame between widget mount and the microtask running where:
- `SuggestionsCard` returns `SizedBox.shrink()` (suggestions empty, not loading)
- `StatsCard` returns `SizedBox.shrink()` (stats null, not loading)

This is identical to the pre-existing behaviour (a one-frame gap before the spinner appeared) and is **not a regression**. Plan review #1 already flagged it as an optional improvement (`isSuggestionsLoading: !service.isGuest, isStatsLoading: !service.isGuest` in `build()`); the implementation did not adopt that suggestion, which is fine.

### 2. `error` is never cleared on successful retry (pre-existing, not introduced)

`copyWith` keeps `error: error ?? this.error`, so once an error is set on either loader, it persists across subsequent successful reloads (e.g. `HomeAppResumed` reloading suggestions). This bug exists on `master`; the rename did not touch it. Out of scope for this milestone — flagging for awareness.

### 3. Minor height delta in `_StatsShimmer` vs real `StatsCard` (~2 px)

Real `StatsCard` height = `14` (top spacer) + 5 × `Text` lines in `bodyMedium` (typically ≈ `20` each) + `14` (bottom spacer) ≈ **128**.
`_StatsShimmer` height = `14` + 5 × `14` (shimmer line) + 4 × `8` (gaps) + `14` = **130**.

A ~2px shift when the swap happens. Not perceptible in practice; mentioned for completeness — matches the spec note verbatim, so no action required.

### 4. Unused locals in `SuggestionsCard.build()` on the shimmer path (cosmetic)

When the shimmer guard returns early, the locals `vm`, `onSurface`, `title`, and `l10n` computed at the top of `build` are unreached. (Actually `title` is only computed after the guards, so it's fine; `vm`, `onSurface`, `l10n` are computed before.) Dart compiles this cleanly — the cost is negligible. No fix needed.

## Positive notes

- Split into two flags (`isSuggestionsLoading` / `isStatsLoading`) is the right granularity given that `HomeAppResumed` reloads only suggestions and `StatsInvalidated` reloads only stats — a single flag would either over-shimmer or under-shimmer.
- Both shimmer widgets are `StatelessWidget` with `const` constructors and use only theme colors (no hardcoded values), so they adapt to light/dark mode automatically.
- The outer container geometry (margins, padding, corner radius, border alpha) of `_SuggestionsShimmer` matches the real card exactly, so the swap from shimmer → content is layout-stable.
- The hairline divider in `_StatsShimmer` reuses the real card's `1 / devicePixelRatio` + `theme.dividerColor` pattern.
- Guest behaviour preserved: both shimmer guards include `!state.isGuest`, so guests still see `SizedBox.shrink()` (no shimmer flicker on app launch before auth).
- `HomeState.copyWith` rewrite to an expression body is a stylistic cleanup; behaviour preserved.

REVIEW_PASS
