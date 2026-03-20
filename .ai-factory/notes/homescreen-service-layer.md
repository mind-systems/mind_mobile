# HomeScreen Service Layer

## Problem

`SuggestionsCard` and `StatsCard` call `App.shared.userApi` and `App.shared.liveSessionNotifier` directly from presentation widgets. HomeModule has no Service, no ViewModel, and no proper assembly.

## Target architecture (follows ProfileModule pattern)

```
HomeModule.buildHomeScreen()
    │
    ├── creates HomeService(userApi, liveSessionNotifier, userNotifier)
    ├── creates HomeCoordinator(context)
    │
    └── ProviderScope(overrides: [homeViewModelProvider])
          └── HomeScreen
                ├── SuggestionsCard  ── watches homeViewModelProvider
                └── StatsCard        ── watches homeViewModelProvider
```

## New files to create

### Models: `lib/HomeModule/Presentation/HomeScreen/Models/`

**HomeDTOs.dart** — DTOs and typed events:
- `SuggestionItemDTO` — `id`, `title`
- `StatsDTO` — `totalSessions`, `totalDuration` (pre-formatted string), `currentStreak` (pre-formatted), `longestStreak` (pre-formatted), `lastSessionDate` (pre-formatted)
- `sealed class HomeEvent` with subtypes: `StatsInvalidated`, `HomeSessionExpired`

**HomeState.dart** — ViewModel state:
- `suggestions: List<SuggestionItemDTO>`, `stats: StatsDTO?`, `isLoading: bool`, `error: String?`
- `copyWith()`, `factory HomeState.initial()`

### Service interface: `lib/HomeModule/Presentation/HomeScreen/IHomeService.dart`

```dart
abstract class IHomeService {
  Future<List<SuggestionItemDTO>> fetchSuggestions();
  Future<StatsDTO> fetchStats();
  Stream<HomeEvent> observeChanges();
}
```

### Concrete service: `lib/HomeModule/HomeService.dart`

Implements `IHomeService`. Constructor takes `IUserApi`, `LiveBreathSessionNotifier`, `UserNotifier`.

- `fetchSuggestions()` — if GuestState, return `[]`. Otherwise call `userApi.fetchSuggestions(period.queryValue)`, map `SuggestionDTO` → `SuggestionItemDTO`
- `fetchStats()` — if GuestState, return null. Otherwise call `userApi.fetchStats()`, map `UserStatsDTO` → `StatsDTO` with formatting (move `_formatDuration` and `_formatDate` from StatsCard here)
- `observeChanges()` — merge `liveSessionNotifier.events` (filter `LiveBreathSessionEnded` → `StatsInvalidated`) with `userNotifier.stream` (filter `GuestState` → `HomeSessionExpired`)

### ViewModel: `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`

`NotifierProvider<HomeViewModel, HomeState>` with throw-by-default (same as `profileViewModelProvider`).

`build()`: subscribe to `service.observeChanges()`, fire-and-forget `_loadSuggestions()` + `_loadStats()`, return `HomeState.initial()`.

Event handling: `StatsInvalidated` → reload stats, `HomeSessionExpired` → reset to initial.

## Files to modify

### `lib/HomeModule/HomeModule.dart`

Wire like ProfileModule — create `HomeService`, `HomeCoordinator`, wrap in `ProviderScope` with `homeViewModelProvider` override.

### `lib/HomeModule/Presentation/HomeScreen/Widgets/SuggestionsCard.dart`

- Remove `suggestionsFutureProvider`, imports of `App`, `SuggestionDTO`, `TimeOfDayHelper`
- Watch `homeViewModelProvider`, read `state.suggestions`

### `lib/HomeModule/Presentation/HomeScreen/Widgets/StatsCard.dart`

- Remove `userStatsFutureProvider`, `_eventSub` subscription, `_formatDuration()`, `_formatDate()`
- Convert `ConsumerStatefulWidget` → `ConsumerWidget`
- Watch `homeViewModelProvider`, read `state.stats`
- If `stats == null` → `SizedBox.shrink()`

### `lib/HomeModule/Presentation/HomeScreen/HomeScreen.dart`

- Remove `coordinator` constructor param (ViewModel gets it via DI)

## Reference implementation

`ProfileModule` is the closest analog — same pattern, same wiring:
- `lib/ProfileModule/ProfileModule.dart` — assembly
- `lib/ProfileModule/ProfileService.dart` — concrete service
- `lib/ProfileModule/Presentation/ProfileScreen/IProfileService.dart` — interface
- `lib/ProfileModule/Presentation/ProfileScreen/ProfileViewModel.dart` — ViewModel
- `lib/ProfileModule/Presentation/ProfileScreen/Models/ProfileDTOs.dart` — DTOs
- `lib/ProfileModule/Presentation/ProfileScreen/Models/ProfileState.dart` — state
