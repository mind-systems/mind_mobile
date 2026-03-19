# Plan: Time-of-Day Suggestions Integration

## Context
Add a suggestions feature to the HomeScreen that fetches personalized suggestions from the API based on the current time of day (morning/midday/evening). The feature uses a pure Dart time-of-day helper, a new `fetchSuggestions` endpoint on `IUserApi`, a Riverpod `FutureProvider`, and a widget embedded in the HomeScreen scroll view.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Time-of-day helper and API layer

- [x] **Task 1: Create TimeOfDay helper**
  Files: `lib/Core/TimeOfDayHelper.dart`
  Create a pure Dart utility that maps a `DateTime` to a time-of-day segment. Define an enum `DayPeriod` with values `morning`, `midday`, `evening`. Implement a function `DayPeriod getDayPeriod(DateTime dateTime)` that returns `morning` for 05:00–11:59, `midday` for 12:00–16:59, and `evening` for 17:00–04:59. Add a `String get queryValue` getter on the enum that returns the lowercase name (used as the API query parameter). This file must have zero Flutter imports — pure Dart only.

- [x] **Task 2: Create SuggestionDTO response model**
  Files: `lib/User/Models/SuggestionDTO.dart`
  Create a response DTO following the existing `UserStatsDTO` pattern. Fields: `String id`, `String title`, `String description`, `String? iconUrl`. Add a `factory SuggestionDTO.fromJson(Map<String, dynamic> json)` constructor with explicit casts and null-safe fallbacks (same style as `UserStatsDTO.fromJson`). Pure Dart, no Flutter imports.

- [x] **Task 3: Add `fetchSuggestions` to IUserApi and UserApi**
  Files: `lib/User/IUserApi.dart`, `lib/Core/Api/UserApi.dart`
  Add `Future<List<SuggestionDTO>> fetchSuggestions(String timeOfDay)` to the `IUserApi` interface. Implement it in `UserApi`: call `_http.get('/users/me/suggestions', queryParameters: {'timeOfDay': timeOfDay})`, cast `response.data` to `List<dynamic>`, and map each element through `SuggestionDTO.fromJson`. Follow the exact pattern of `fetchStats()` — typed return, explicit cast, no raw Maps.

### Phase 2: Riverpod provider and widget

- [x] **Task 4: Create SuggestionsCard widget with FutureProvider**
  Files: `lib/HomeModule/Presentation/HomeScreen/Widgets/SuggestionsCard.dart`
  Create a `FutureProvider.autoDispose<List<SuggestionDTO>>` named `suggestionsFutureProvider` at the top of the file. The provider body calls `getDayPeriod(DateTime.now())` to determine the current period, then calls `App.shared.userApi.fetchSuggestions(period.queryValue)`. Follow the `userStatsFutureProvider` pattern from `StatsCard.dart` exactly.

  Create `SuggestionsCard` as a `ConsumerWidget` (no stream subscription needed, unlike StatsCard). In `build`, `ref.watch(suggestionsFutureProvider)` and use `.when(loading:, error:, data:)`:
  - `loading` — a `SizedBox` with fixed height and centered `CircularProgressIndicator` (same as StatsCard).
  - `error` — a `Padding` with a localized error text in `bodyMedium` style.
  - `data` — if the list is empty, return `SizedBox.shrink()`. Otherwise render a `Column` with a section header (`titleSmall` text) and a list of suggestion items. Each item shows `title` and `description` using `bodyMedium`/`bodySmall` text styles. Use `theme.dividerColor` for separators between items, matching StatsCard's 1-physical-pixel divider pattern.

- [x] **Task 5: Add l10n strings for suggestions**
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`
  Add localized strings for the suggestions section. Keys to add:
  - `homeSuggestionsTitle` — section header (EN: "Suggestions for you", RU: "Рекомендации для вас")
  - `homeSuggestionsError` — error state (EN: "Could not load suggestions", RU: "Не удалось загрузить рекомендации")

  After editing the ARB files, run `flutter gen-l10n` (or the project's generation command) to regenerate the `AppLocalizations` class. Use these l10n keys in `SuggestionsCard` instead of hardcoded strings.

- [x] **Task 6: Wire SuggestionsCard into HomeScreen**
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeScreen.dart`
  Import `SuggestionsCard` and add it as a new `SliverToBoxAdapter(child: SuggestionsCard())` in the `CustomScrollView.slivers` list, placed **above** the existing `StatsCard` sliver. This follows the same embedding pattern StatsCard uses — no ProviderScope override needed since the FutureProvider accesses `App.shared` directly.

## Commit Plan
- **Commit 1** (after tasks 1-3): "Add time-of-day helper and fetchSuggestions API endpoint"
- **Commit 2** (after tasks 4-6): "Add SuggestionsCard widget and wire into HomeScreen"
