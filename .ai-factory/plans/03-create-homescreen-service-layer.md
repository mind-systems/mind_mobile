# Plan: Create HomeScreen Service Layer

## Context

HomeModule currently violates the architecture boundary: `SuggestionsCard` and `StatsCard` call `App.shared.userApi` and `App.shared.liveSessionNotifier` directly from presentation widgets, bypassing any Service or ViewModel. This milestone introduces `IHomeService`, `HomeService`, `HomeViewModel`, DTOs, and state following the ProfileModule pattern, so the HomeScreen conforms to the same layered architecture as the rest of the app.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Reference

ProfileModule is the exact pattern to follow:
- `lib/ProfileModule/ProfileModule.dart` — assembly with `ProviderScope.overrideWith`
- `lib/ProfileModule/ProfileService.dart` — concrete service, pure Dart, constructor-injected notifiers
- `lib/ProfileModule/Presentation/ProfileScreen/IProfileService.dart` — interface at module boundary
- `lib/ProfileModule/Presentation/ProfileScreen/ProfileViewModel.dart` — `Notifier<ProfileState>`, `NotifierProvider` with throw-by-default factory
- `lib/ProfileModule/Presentation/ProfileScreen/Models/ProfileDTOs.dart` — sealed event + DTO classes
- `lib/ProfileModule/Presentation/ProfileScreen/Models/ProfileState.dart` — immutable state with `copyWith`

## Tasks

### Phase 1: Models and interfaces

- [x] **Task 1: Create HomeDTOs and HomeState**
  Files: `lib/HomeModule/Presentation/HomeScreen/Models/HomeDTOs.dart`, `lib/HomeModule/Presentation/HomeScreen/Models/HomeState.dart`

  **HomeDTOs.dart** — Define:
  - `SuggestionItemDTO` with fields `id` (String), `title` (String). Plain class, const constructor.
  - `StatsDTO` with fields `totalSessions` (int), `totalDuration` (String, pre-formatted), `currentStreak` (String, pre-formatted), `longestStreak` (String, pre-formatted), `lastSessionDate` (String, pre-formatted). Plain class, const constructor. All string fields hold display-ready text (formatting moves from StatsCard to Service).
  - `sealed class HomeEvent` with subtypes: `StatsInvalidated extends HomeEvent`, `HomeSessionExpired extends HomeEvent`.

  **HomeState.dart** — Define:
  - Fields: `suggestions` (List\<SuggestionItemDTO\>), `stats` (StatsDTO?), `isGuest` (bool), `isLoading` (bool), `error` (String?).
  - `const` constructor with defaults: `suggestions: const []`, `stats: null`, `isGuest: true`, `isLoading: false`, `error: null`.
  - `factory HomeState.initial()` returning the const default.
  - `copyWith()` method (manual, same style as `ProfileState`).

  Follow `ProfileDTOs.dart` and `ProfileState.dart` for exact code style.

- [x] **Task 2: Create IHomeService interface** (depends on Task 1)
  Files: `lib/HomeModule/Presentation/HomeScreen/IHomeService.dart`

  Declare the abstract class at the module boundary (same location pattern as `IProfileService.dart`):
  ```
  abstract class IHomeService {
    bool get isGuest;
    Future<List<SuggestionItemDTO>> fetchSuggestions();
    Future<StatsDTO?> fetchStats();
    Stream<HomeEvent> observeChanges();
  }
  ```
  - `isGuest` — synchronous getter, checks `UserNotifier.currentState is GuestState` (the ViewModel reads this in `build()` to set initial `isGuest`).
  - `fetchSuggestions()` — returns suggestion DTOs (empty list for guests).
  - `fetchStats()` — returns stats DTO or null for guests.
  - `observeChanges()` — event stream for reactivity.

  Import `HomeDTOs.dart` for the DTO and event types.

### Phase 2: Concrete service and ViewModel

- [x] **Task 3: Create HomeService** (depends on Task 2)
  Files: `lib/HomeModule/HomeService.dart`

  Implements `IHomeService`. Constructor takes `IUserApi`, `LiveBreathSessionNotifier`, `UserNotifier` (same constructor-injection pattern as `ProfileService`). No `App.shared` access inside the service. Pure Dart — no Flutter imports.

  - `isGuest` — returns `userNotifier.currentState is GuestState`.
  - `fetchSuggestions()` — if guest, return `[]`. Otherwise call `getDayPeriod(DateTime.now())` (import `TimeOfDayHelper`), then `userApi.fetchSuggestions(period.queryValue)`, map each `SuggestionDTO` to `SuggestionItemDTO(id: s.id, title: s.title)`.
  - `fetchStats()` — if guest, return `null`. Otherwise call `userApi.fetchStats()`, convert `UserStatsDTO` to `StatsDTO` with pre-formatted strings. Move `_formatDuration` and `_formatDate` logic from `StatsCard` here as private methods. Replace hardcoded Russian month names with l10n-agnostic ISO date formatting (use `DateTime.parse` + day/month/year numeric format like `"dd.MM.yyyy"`, since the existing Russian month names are a bug).
  - `observeChanges()` — merge two streams with RxDart:
    1. `liveSessionNotifier.events` filtered to `LiveBreathSessionEnded` mapped to `StatsInvalidated()`
    2. `userNotifier.stream` filtered to `GuestState` mapped to `HomeSessionExpired()`

  Reference `ProfileService.dart` for the stream-merging pattern (`.mergeWith()`).

- [x] **Task 4: Create HomeViewModel and provider** (depends on Task 3)
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`

  Declare `homeViewModelProvider` as a top-level `NotifierProvider<HomeViewModel, HomeState>` with a throw-by-default factory (same pattern as `profileViewModelProvider`).

  `HomeViewModel extends Notifier<HomeState>`. Constructor takes `IHomeService service` and `IHomeCoordinator coordinator`.

  `build()`:
  - Subscribe to `service.observeChanges().listen(_onEvent)`, register `ref.onDispose` to cancel.
  - Fire-and-forget `_loadInitialData()` which calls `_loadSuggestions()` and `_loadStats()` concurrently.
  - Return `HomeState.initial().copyWith(isGuest: service.isGuest)`.

  `_loadSuggestions()`:
  - Set `state = state.copyWith(isLoading: true)`.
  - `try` call `service.fetchSuggestions()`, update `state` with result.
  - `catch` — set `state.copyWith(error: ...)`.

  `_loadStats()`:
  - Call `service.fetchStats()`, update `state` with result.
  - On error, set `state.copyWith(error: ...)`.

  `_onEvent(HomeEvent)`:
  - `StatsInvalidated` — call `_loadStats()` to refresh.
  - `HomeSessionExpired` — reset to `HomeState.initial()` (guest mode, empty data).

  Navigation action methods (delegating to coordinator):
  - `onBreathTap()` — `coordinator.openBreath()`
  - `onComingSoonTap()` — `coordinator.openComingSoon()`
  - `onProfileTap()` — `coordinator.openProfile()`
  - `onSuggestionTap(String sessionId)` — `coordinator.openSuggestion(sessionId)`

### Phase 3: Wiring and widget migration

- [x] **Task 5: Extend IHomeCoordinator and HomeCoordinator with openSuggestion** (depends on Task 4)
  Files: `lib/HomeModule/Presentation/HomeScreen/IHomeCoordinator.dart`, `lib/HomeModule/Presentation/HomeScreen/HomeCoordinator.dart`

  `SuggestionsCard` currently navigates inline via `context.push(BreathSessionScreen.path, extra: id)`. This should go through the coordinator like all other navigation.

  - Add `void openSuggestion(String sessionId)` to `IHomeCoordinator`.
  - Implement in `HomeCoordinator`: `context.push(BreathSessionScreen.path, extra: sessionId)`. Add `import` for `BreathSessionScreen` from `breath_module`.

- [x] **Task 6: Wire HomeModule.dart** (depends on Task 5)
  Files: `lib/HomeModule/HomeModule.dart`

  Rewrite `buildHomeScreen` to follow the `ProfileModule.buildProfileScreen` pattern exactly:
  1. Construct `HomeService(userApi: App.shared.userApi, liveSessionNotifier: App.shared.liveSessionNotifier, userNotifier: App.shared.userNotifier)`.
  2. Construct `HomeCoordinator(context, userNotifier: App.shared.userNotifier)`.
  3. Return `ProviderScope(overrides: [homeViewModelProvider.overrideWith(() => HomeViewModel(service: service, coordinator: coordinator))], child: const HomeScreen())`.

  Update imports: add `HomeService`, `HomeViewModel` (for provider), `ProviderScope`. Remove the direct `HomeScreen` coordinator param since it no longer takes one.

- [x] **Task 7: Migrate HomeScreen to ConsumerWidget** (depends on Task 6)
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeScreen.dart`

  - Change from `StatelessWidget` to `ConsumerWidget`, add `WidgetRef ref` param to `build`.
  - Remove `final IHomeCoordinator coordinator` constructor field and the `required this.coordinator` param.
  - In `build`, get the ViewModel notifier: `final vm = ref.read(homeViewModelProvider.notifier)`.
  - Replace module grid `onTap` callbacks: `coordinator.openBreath` becomes `vm.onBreathTap`, `coordinator.openComingSoon` becomes `vm.onComingSoonTap`, `coordinator.openProfile` becomes `vm.onProfileTap`.
  - Keep the `const` on `HomeScreen` constructor. Add `flutter_riverpod` import, add import for `HomeViewModel.dart` (for the provider).
  - Remove the `IHomeCoordinator` import.

- [x] **Task 8: Migrate SuggestionsCard to watch ViewModel** (depends on Task 7)
  Files: `lib/HomeModule/Presentation/HomeScreen/Widgets/SuggestionsCard.dart`

  - Delete the `suggestionsFutureProvider` top-level provider entirely.
  - Remove imports: `App`, `TimeOfDayHelper`, `SuggestionDTO`, `go_router`, `BreathSessionScreen`.
  - The widget stays a `ConsumerWidget`.
  - In `build`, read state: `final state = ref.watch(homeViewModelProvider)` and get ViewModel notifier: `final vm = ref.read(homeViewModelProvider.notifier)`.
  - Read `state.suggestions` instead of the old async provider. If `state.isLoading`, show spinner. If `state.suggestions.isEmpty`, return `SizedBox.shrink()`.
  - Replace `SuggestionCarouselItem` onTap: `(id) => vm.onSuggestionTap(id)` instead of inline `context.push`.
  - Add import for `HomeViewModel.dart` (for the provider).
  - `SuggestionsTitle` and `AutoScrollCarousel` rendering remain unchanged.

- [x] **Task 9: Migrate StatsCard to watch ViewModel** (depends on Task 7)
  Files: `lib/HomeModule/Presentation/HomeScreen/Widgets/StatsCard.dart`

  - Delete the `userStatsFutureProvider` top-level provider entirely.
  - Remove imports: `dart:async`, `App`, `LiveBreathSessionEvent`, `UserStatsDTO`.
  - Convert from `ConsumerStatefulWidget` to `ConsumerWidget` (remove `_StatsCardState`, `initState`, `dispose`, `_eventSub`).
  - Delete `_formatDuration` and `_formatDate` methods (they moved to `HomeService`).
  - In `build`, read state: `final stats = ref.watch(homeViewModelProvider).stats`.
  - If `stats == null`, return `SizedBox.shrink()`.
  - Otherwise render the stats column using pre-formatted DTO string fields (`stats.totalDuration`, `stats.currentStreak`, etc.). Use l10n keys instead of hardcoded Russian strings for labels.
  - Add import for `HomeViewModel.dart` (for the provider), `flutter_riverpod`.

## Commit Plan
- **Commit 1** (after tasks 1-4): "Add HomeScreen service layer: DTOs, state, IHomeService, HomeService, HomeViewModel"
- **Commit 2** (after tasks 5-9): "Wire HomeModule and migrate widgets to watch HomeViewModel"
