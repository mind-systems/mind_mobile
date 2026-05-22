# HomeScreen shimmer placeholders during loading

## Problem

During initial load and after a gRPC reconnect triggers a reload, `HomeScreen` shows nothing or a spinner while data is fetching. `SuggestionsCard` renders a raw `CircularProgressIndicator` when `isLoading`, and `StatsCard` returns `SizedBox.shrink()` while `stats == null` — even for an authenticated user who is simply waiting for the network response.

The result is a jarring layout shift: the screen looks broken (missing content) until data arrives.

## Target behaviour

For an authenticated user (`isGuest == false`), while suggestions or stats are loading, show skeleton shimmer placeholders that match the shape and size of the real content. The placeholders disappear when data arrives and are replaced by the real content. Guest users continue to see nothing (no shimmer, no empty state).

`shimmer: ^3.0.0` is already in `pubspec.yaml` — no new dependency needed.

## State changes

### `lib/HomeModule/Presentation/HomeScreen/Models/HomeState.dart`

Add `isStatsLoading: bool` alongside the existing `isLoading` (which covers suggestions). Rename `isLoading` to `isSuggestionsLoading` for clarity — update all references:
- `HomeViewModel._loadSuggestions()` — sets/clears the flag
- `SuggestionsCard` — reads the flag

```dart
class HomeState {
  final List<SuggestionItemDTO> suggestions;
  final StatsDTO? stats;
  final bool isGuest;
  final bool isSuggestionsLoading;
  final bool isStatsLoading;
  final String? error;

  const HomeState({
    this.suggestions = const [],
    this.stats,
    this.isGuest = true,
    this.isSuggestionsLoading = false,
    this.isStatsLoading = false,
    this.error,
  });

  factory HomeState.initial() => const HomeState();

  HomeState copyWith({
    List<SuggestionItemDTO>? suggestions,
    StatsDTO? stats,
    bool? isGuest,
    bool? isSuggestionsLoading,
    bool? isStatsLoading,
    String? error,
  }) => HomeState(
    suggestions: suggestions ?? this.suggestions,
    stats: stats ?? this.stats,
    isGuest: isGuest ?? this.isGuest,
    isSuggestionsLoading: isSuggestionsLoading ?? this.isSuggestionsLoading,
    isStatsLoading: isStatsLoading ?? this.isStatsLoading,
    error: error ?? this.error,
  );
}
```

## ViewModel changes

### `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`

`_loadSuggestions()` — replace `isLoading` with `isSuggestionsLoading`:

```dart
Future<void> _loadSuggestions() async {
  state = state.copyWith(isSuggestionsLoading: true);
  try {
    final suggestions = await service.fetchSuggestions();
    state = state.copyWith(suggestions: suggestions, isSuggestionsLoading: false);
  } catch (e) {
    state = state.copyWith(isSuggestionsLoading: false, error: e.toString());
  }
}
```

`_loadStats()` — add loading flag:

```dart
Future<void> _loadStats() async {
  state = state.copyWith(isStatsLoading: true);
  try {
    final stats = await service.fetchStats();
    if (stats != null) {
      state = state.copyWith(stats: stats, isStatsLoading: false);
    } else {
      state = state.copyWith(isStatsLoading: false);
    }
  } catch (e) {
    state = state.copyWith(isStatsLoading: false, error: e.toString());
  }
}
```

`_onEvent` — `HomeSessionExpired` resets back to `initial()` which already has both flags `false`. No change needed there. `HomeAuthenticated` sets `isGuest: false` then calls `_loadInitialData()` which will set both flags — no change needed.

## Widget changes

### `lib/HomeModule/Presentation/HomeScreen/Widgets/SuggestionsCard.dart`

Replace the `CircularProgressIndicator` block with a shimmer placeholder that matches the real card's geometry.

**Shimmer card dimensions:**
- Same outer container: `margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12)`, `BorderRadius.circular(kCardCornerRadius)`, border
- Title shimmer row: `height: 14`, `width: ~120`, `borderRadius: 7`, top padding 12
- Carousel shimmer: three rounded rectangles side by side, `height: 88`, each ~44% of card width, `borderRadius: kCardCornerRadius`
- Bottom padding 8

```dart
if (!state.isGuest && state.isSuggestionsLoading) {
  return _SuggestionsShimmer();
}
if (state.suggestions.isEmpty) return const SizedBox.shrink();
```

`_SuggestionsShimmer` is a private `StatelessWidget` at the bottom of the file:

```dart
class _SuggestionsShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest;
    final highlight = theme.colorScheme.surface;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kCardCornerRadius),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // title row
              Container(height: 14, width: 120, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(7))),
              const SizedBox(height: 12),
              // carousel row — three cards
              Row(
                children: List.generate(3, (i) => Expanded(
                  child: Container(
                    height: 88,
                    margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                    decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(kCardCornerRadius)),
                  ),
                )),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
```

### `lib/HomeModule/Presentation/HomeScreen/Widgets/StatsCard.dart`

Add shimmer placeholder for when stats are loading. Current guard:

```dart
if (stats == null) return const SizedBox.shrink();
```

Replace with:

```dart
final state = ref.watch(homeViewModelProvider);

if (!state.isGuest && state.isStatsLoading) {
  return _StatsShimmer();
}
if (state.stats == null) return const SizedBox.shrink();
final stats = state.stats!;
// ... rest unchanged
```

`_StatsShimmer` at the bottom of the file — shimmer rows matching the 5 text lines in the real `StatsCard`, plus the bottom divider:

```dart
class _StatsShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest;
    final highlight = theme.colorScheme.surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                _shimmerLine(base, width: 160),
                const SizedBox(height: 8),
                _shimmerLine(base, width: 200),
                const SizedBox(height: 8),
                _shimmerLine(base, width: 180),
                const SizedBox(height: 8),
                _shimmerLine(base, width: 220),
                const SizedBox(height: 8),
                _shimmerLine(base, width: 140),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        Container(
          height: 1 / MediaQuery.of(context).devicePixelRatio,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: theme.dividerColor,
        ),
      ],
    );
  }

  Widget _shimmerLine(Color color, {required double width}) {
    return Container(
      height: 14,
      width: width,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
    );
  }
}
```

## Visual result

On first load and after reconnect:
- Authenticated user sees a shimmering card outline where suggestions will appear, and 5 shimmering text lines where stats will appear
- When data arrives, placeholders are replaced by real content with no layout jump (the shimmer has the same height footprint as the real content)
- Guest users see nothing — unchanged behaviour
