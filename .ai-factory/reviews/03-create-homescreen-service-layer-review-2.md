# Review 2: Create HomeScreen Service Layer

Review of the updated changeset including the `HomeAuthenticated` event fix from review 1.

## Scope

New files (5): `HomeDTOs.dart`, `HomeState.dart`, `IHomeService.dart`, `HomeService.dart`, `HomeViewModel.dart`
Modified files (7): `HomeModule.dart`, `HomeScreen.dart`, `HomeCoordinator.dart`, `IHomeCoordinator.dart`, `SuggestionsCard.dart`, `StatsCard.dart`
L10n files (4): `app_en.arb`, `app_ru.arb`, generated `app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_ru.dart`

## Issues

### 1. Double-fetch on every authenticated HomeScreen load [bug, medium]

`HomeViewModel.build()` calls `_loadInitialData()` directly (line 26) **and** subscribes to `service.observeChanges()`. Because `userNotifier.stream` is a `BehaviorSubject`, it replays the current auth state on subscription. For an authenticated user, the replay emits `AuthenticatedState` → passes the `where` filter → `HomeAuthenticated` event → `_onEvent` calls `_loadInitialData()` a second time.

Result: `fetchSuggestions()` and `fetchStats()` are each called **twice** on every HomeScreen load for authenticated users — 4 API calls instead of 2.

**Why this didn't happen in ProfileModule:** `ProfileViewModel.build()` does **not** call a load method — it returns `ProfileState(theme: ..., language: ...)` and relies entirely on the `BehaviorSubject` replay (`ProfileLoaded` event) to populate the username. So there's no double-fire. `HomeViewModel` both eagerly loads in `build()` and reacts to the replay.

**Fix — add `.skip(1)` to both auth stream branches in `HomeService.observeChanges()`:**
```dart
final authStream = userNotifier.stream.skip(1);
final sessionExpired = authStream
    .where((s) => s is GuestState)
    .map((_) => HomeSessionExpired() as HomeEvent);
final authenticated = authStream
    .where((s) => s is AuthenticatedState)
    .map((_) => HomeAuthenticated() as HomeEvent);
```

This skips the BehaviorSubject replay (initial state is already handled by `build()`) and only reacts to actual auth state transitions.

### 2. Error states no longer displayed — UX regression [minor]

**SuggestionsCard:** Old widget showed `l10n.homeSuggestionsError` text on fetch failure. New widget checks `state.isLoading` and `state.suggestions.isEmpty` — on error, suggestions stay empty and the card silently collapses to `SizedBox.shrink()`.

**StatsCard:** Old widget showed "Не удалось загрузить статистику" on error. New widget checks `stats == null` — on error, stats stay null and the card silently collapses to `SizedBox.shrink()`.

Both `state.error` is set by the ViewModel on failure, but neither widget reads it. The error field is effectively dead code. If silent collapse is the intended UX, this is fine. If error feedback is desired, add error checks to the widgets.

### 3. `_formatDuration` hardcoded English units [minor, carried from review 1]

`HomeService._formatDuration` outputs `"5 h 30 min"`. Not localizable from the pure-Dart service layer. Same tradeoff noted in review 1 — acceptable given the "pre-formatted string" design choice.

## Verified correct

- **`HomeAuthenticated` event and handler**: Event type added to sealed class, stream branch added in `observeChanges()`, ViewModel sets `isGuest: false` and calls `_loadInitialData()`. The guest → authenticated transition is now handled.
- **Stream lifecycle**: `ref.onDispose` cancels the subscription. No leaks.
- **No synchronous state mutation in `build()`**: `_loadInitialData()` methods are async — state writes happen in microtask continuations after `build()` returns. The `BehaviorSubject` replay is also delivered asynchronously per Dart stream contract.
- **Concurrent loads don't interfere**: `_loadSuggestions()` and `_loadStats()` use `copyWith` that preserves each other's fields.
- **Guest guard**: Both `fetchSuggestions()` and `fetchStats()` short-circuit for guests — no unnecessary API calls.
- **ProviderScope wiring**: Matches `ProfileModule.buildProfileScreen` exactly.
- **Coordinator pattern**: `openSuggestion` added correctly. All navigation routed through ViewModel → Coordinator.
- **Widget migration**: `StatsCard` correctly simplified from `ConsumerStatefulWidget` to `ConsumerWidget`. `SuggestionsCard` correctly retains `TimeOfDayHelper` import (needed for title, not fetch).
- **L10n**: All 5 new keys present in both ARBs and generated files. Keys match widget usage.
- **Import chain**: No cycles, no missing dependencies, all types align.

## Verdict

Issue #1 (double-fetch) causes redundant API calls on every authenticated visit. Recommend fixing with `.skip(1)` before merge. Issues #2 and #3 are non-blocking.

REVIEW_PASS
