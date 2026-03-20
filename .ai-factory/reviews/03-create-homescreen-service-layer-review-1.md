# Review: Create HomeScreen Service Layer

## Scope

New files: `HomeDTOs.dart`, `HomeState.dart`, `IHomeService.dart`, `HomeService.dart`, `HomeViewModel.dart`
Modified files: `HomeModule.dart`, `HomeScreen.dart`, `HomeCoordinator.dart`, `IHomeCoordinator.dart`, `SuggestionsCard.dart`, `StatsCard.dart`, l10n ARB + generated files

## Architecture conformance

The implementation faithfully follows the ProfileModule pattern: throw-by-default `NotifierProvider`, constructor-injected Service + Coordinator, `ProviderScope` override in `HomeModule.buildHomeScreen`, sealed event class, DTOs at the module boundary. No architecture violations found.

## Issues

### 1. Missing event for guest → authenticated transition [bug, medium]

`HomeService.observeChanges()` emits `HomeSessionExpired` when `UserNotifier` transitions to `GuestState`, but has no event for the reverse transition (`GuestState → AuthenticatedState`).

**Runtime scenario:**
1. App launches in guest mode → `HomeViewModel.build()` sets `isGuest: true`, fetches return empty/null
2. User taps Profile → guest-guard → pushes OnboardingScreen → user logs in
3. `UserNotifier` emits `AuthenticatedState` — but `observeChanges()` filters it out (`where((s) => s is GuestState)`)
4. User pops back to HomeScreen — the widget tree is still alive (GoRouter keeps `/` mounted during push/pop)
5. ViewModel still holds the guest state with no data — suggestions and stats never reload

**Fix:** Add a `HomeAuthenticated` event type to `HomeDTOs.dart`. In `observeChanges()`, add a third stream branch: `userNotifier.stream.where((s) => s is AuthenticatedState).map((_) => HomeAuthenticated())`. In `HomeViewModel._onEvent`, handle `HomeAuthenticated` by setting `isGuest: false` and calling `_loadInitialData()`.

### 2. `_formatDuration` uses hardcoded English units [minor]

`HomeService._formatDuration` outputs `"5 h 30 min"`. The old `StatsCard` code used Russian `"5 ч 30 мин"`. Neither is correct for a bilingual app. Since the Service is pure Dart with no access to `AppLocalizations`, l10n-aware formatting isn't possible here.

**Location:** `HomeService.dart:60`

**Options:**
- (a) Pass raw `int totalDurationSeconds` in `StatsDTO` and format in `StatsCard` using l10n
- (b) Accept "h/min" as l10n-neutral abbreviations (current choice matches the plan's "pre-formatted" design)

Not a crash or correctness bug — flagging as a conscious tradeoff.

### 3. `copyWith` cannot null-out nullable fields [latent, non-blocking]

`HomeState.copyWith` uses `??` for `stats` and `error`, so `copyWith(stats: null)` preserves the existing value instead of clearing it. This doesn't cause a problem in the current code because `HomeSessionExpired` resets via `HomeState.initial()` (not `copyWith`), and `_loadStats` only ever sets a non-null `StatsDTO`. Same pattern as `ProfileState` — this is a codebase convention, not a regression.

## Verified correct

- **Stream lifecycle**: `ref.onDispose(() => subscription.cancel())` properly cleans up the event stream subscription.
- **No synchronous state mutation during `build()`**: `_loadInitialData()` methods are async — state mutations happen in microtask continuations after `build()` returns. The `BehaviorSubject` replay from `userNotifier.stream` is also delivered asynchronously by Dart's stream contract.
- **Concurrent loads**: `_loadSuggestions()` and `_loadStats()` run in parallel without interfering. Each uses `copyWith` that preserves the other's fields.
- **Guest guard in Service**: `fetchSuggestions()` and `fetchStats()` correctly short-circuit for guests, avoiding unnecessary API calls.
- **Coordinator wiring**: `openSuggestion` added to both interface and implementation. Navigation previously inline in `SuggestionsCard` now goes through the coordinator pattern.
- **L10n keys**: `homeStatsTotalSessions`, `homeStatsDuration`, `homeStatsCurrentStreak`, `homeStatsBestStreak`, `homeStatsLastSession` added to both `app_en.arb` and `app_ru.arb`, generated files are in sync.
- **HomeModule wiring**: Matches `ProfileModule.buildProfileScreen` exactly — same `ProviderScope.overrideWith` pattern, same constructor injection.
- **Widget migration**: `SuggestionsCard` correctly retains `TimeOfDayHelper` import (needed for `getSuggestionsTitle`). `StatsCard` simplified from `ConsumerStatefulWidget` to `ConsumerWidget` — all subscription/formatting logic properly moved to Service/ViewModel.

## Verdict

Issue #1 (missing auth event) is a correctness bug that causes the HomeScreen to stay in guest state after login. Recommend fixing before merge. Issues #2 and #3 are non-blocking.

REVIEW_PASS_WITH_NOTES
