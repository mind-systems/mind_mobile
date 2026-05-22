# Plan: Shimmer placeholders on HomeScreen during loading

## Context
Replace the raw `CircularProgressIndicator` in `SuggestionsCard` and the empty `SizedBox.shrink()` in `StatsCard` with shimmer skeleton placeholders that match the real content's geometry, so authenticated users see a meaningful loading state on first load and after a gRPC reconnect. Full spec in `.ai-factory/notes/20-home-shimmer-loading.md`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: State and ViewModel

- [x] **Task 1: Split loading flag in `HomeState`**
  Files: `lib/HomeModule/Presentation/HomeScreen/Models/HomeState.dart`
  Rename `isLoading` to `isSuggestionsLoading` and add `isStatsLoading: bool` (default `false`). Update the constructor, `HomeState.initial()` factory (no change needed — defaults still apply), and `copyWith` to accept and forward both new fields. Preserve existing field ordering: `suggestions`, `stats`, `isGuest`, `isSuggestionsLoading`, `isStatsLoading`, `error`.

- [x] **Task 2: Wire both loading flags in `HomeViewModel`** (depends on Task 1)
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`
  In `_loadSuggestions()`, replace `isLoading` references with `isSuggestionsLoading` (set `true` before the fetch, `false` in both success and `catch` branches). In `_loadStats()`, set `isStatsLoading: true` before the fetch and clear it to `false` in both the success path (whether `stats` is null or not) and the `catch` path. `_onEvent` cases (`HomeSessionExpired`, `HomeAuthenticated`, `HomeAppResumed`, `HomeGrpcReconnected`, `StatsInvalidated`) require no further changes — they already call `_loadInitialData()` / `_loadStats()` / `_loadSuggestions()` which now handle the flags correctly.

### Phase 2: Shimmer widgets

- [x] **Task 3: Add `_SuggestionsShimmer` to `SuggestionsCard`** (depends on Task 2)
  Files: `lib/HomeModule/Presentation/HomeScreen/Widgets/SuggestionsCard.dart`
  Import `package:shimmer/shimmer.dart`. Replace the existing `if (state.isLoading) { ... CircularProgressIndicator ... }` block with `if (!state.isGuest && state.isSuggestionsLoading) return const _SuggestionsShimmer();`. Keep the `state.suggestions.isEmpty` guard immediately after so guests with no data still see `SizedBox.shrink()`. Add a private `_SuggestionsShimmer` `StatelessWidget` at the bottom of the file that renders:
  - Outer `Container` with `margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12)`, `BorderRadius.circular(kCardCornerRadius)`, and border `theme.colorScheme.onSurface.withValues(alpha: 0.1)` — identical to the real card.
  - Inside, `Shimmer.fromColors` with `baseColor = theme.colorScheme.surfaceContainerHighest` and `highlightColor = theme.colorScheme.surface`.
  - Inner `Padding(EdgeInsets.fromLTRB(16, 12, 16, 8))` containing a `Column(crossAxisAlignment: start)`:
    - Title row: `Container(height: 14, width: 120)` with `BorderRadius.circular(7)` filled with `baseColor`.
    - `SizedBox(height: 12)`.
    - `Row` of three `Expanded` children, each a `Container(height: 88)` with `BorderRadius.circular(kCardCornerRadius)` filled with `baseColor`, with `margin: EdgeInsets.only(right: 8)` on the first two.
    - Trailing `SizedBox(height: 8)`.
  Use `kCardCornerRadius` from `mind_ui` (already imported in this file).

- [x] **Task 4: Add `_StatsShimmer` to `StatsCard`** (depends on Task 2)
  Files: `lib/HomeModule/Presentation/HomeScreen/Widgets/StatsCard.dart`
  Import `package:shimmer/shimmer.dart`. Change `build` to read the full state: `final state = ref.watch(homeViewModelProvider);`. Add `if (!state.isGuest && state.isStatsLoading) return const _StatsShimmer();` before the existing `stats == null` guard. After the guards, bind `final stats = state.stats!;` and leave the rest of the rendering unchanged. Add a private `_StatsShimmer` `StatelessWidget` at the bottom that returns a `Column(crossAxisAlignment: start)` containing:
  - `Shimmer.fromColors` (same `baseColor`/`highlightColor` as Task 3) wrapping `Padding(EdgeInsets.symmetric(horizontal: 16))` with a `Column` of `SizedBox(height: 14)`, five `_shimmerLine` entries of widths `160`, `200`, `180`, `220`, `140` separated by `SizedBox(height: 8)`, then `SizedBox(height: 14)`.
  - Below the shimmer, the same hairline `Container(height: 1 / MediaQuery.of(context).devicePixelRatio, margin: EdgeInsets.symmetric(horizontal: 16), color: theme.dividerColor)` used by the real card.
  - Private helper `Widget _shimmerLine(Color color, {required double width})` returning a `Container(height: 14, width: width)` with `BorderRadius.circular(7)` filled with `color`.

## Commit Plan
- **Commit 1** (after tasks 1-2): "Split HomeState loading flag into suggestions and stats"
- **Commit 2** (after tasks 3-4): "Render shimmer placeholders on HomeScreen during loading"
