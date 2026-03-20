## Code Review Summary

**Files Reviewed:** 16
**Risk Level:** 🟡 Medium

### Context Gates

- **ARCHITECTURE.md** — WARN: Architecture rules are followed well. Service is pure Dart, ViewModel depends on interfaces, Screen doesn't touch domain. The layer stack is correct. No violations.
- **RULES.md** — not present, skipped.
- **ROADMAP.md** — OK: milestone 3 is marked complete and matches the implemented scope.

### Critical Issues

1. **BehaviorSubject replay causes double data load on every HomeScreen mount**
   `HomeService.observeChanges()` (line 47-57) subscribes to `userNotifier.stream`, which is a `BehaviorSubject`. On subscription, it immediately replays the current auth state. For authenticated users, this means `HomeAuthenticated` fires right after `build()` already called `_loadInitialData()`, causing `fetchSuggestions()` and `fetchStats()` to each run twice (4 API calls instead of 2 on every HomeScreen visit).

   For comparison, `ProfileService.observeProfile()` also gets BehaviorSubject replay, but it *intentionally* uses it to populate `userName` — there's no separate initial load in `ProfileViewModel.build()`. In `HomeViewModel.build()`, `_loadInitialData()` is explicitly called, so the replay is redundant and harmful.

   **Fix:** Skip the initial replay on the `userNotifier.stream` branches in `observeChanges()`:
   ```dart
   Stream<HomeEvent> observeChanges() {
     final statsInvalidated = liveSessionNotifier.events
         .where((e) => e is LiveBreathSessionEnded)
         .map((_) => StatsInvalidated() as HomeEvent);
     final userStream = userNotifier.stream.skip(1);
     final sessionExpired = userStream
         .where((s) => s is GuestState)
         .map((_) => HomeSessionExpired() as HomeEvent);
     final authenticated = userStream
         .where((s) => s is AuthenticatedState)
         .map((_) => HomeAuthenticated() as HomeEvent);
     return statsInvalidated.mergeWith([sessionExpired, authenticated]);
   }
   ```
   `liveSessionNotifier.events` uses `PublishSubject` (no replay), so it needs no skip.

2. **`_formatDuration` hardcodes English units — localization regression for Russian users**
   `HomeService._formatDuration()` (line 60-64) outputs `'$h h $m min'`. The old `StatsCard` used Russian (`'$h ч $m мин'`). Since `HomeService` is pure Dart with no `BuildContext`, it can't access l10n. Meanwhile the stats *labels* (`homeStatsDuration`, etc.) are properly localized, so Russian users will see mixed languages: "Время практики: 5 h 30 min".

   **Fix:** Keep duration components as raw data in `StatsDTO` (e.g. `durationHours: int`, `durationMinutes: int`) and format them in the widget using l10n keys, or add l10n keys for "h" / "min" and pass them to the service.

### Suggestions

3. **`HomeState.copyWith` can't reset `error` to null**
   `HomeState.copyWith()` uses the `??` pattern for nullable fields (`error: error ?? this.error`). Once `error` is set (e.g. a failed `_loadSuggestions`), a subsequent successful load never clears it because `copyWith(error: null)` is a no-op. Currently harmless since no widget reads `state.error`, but it's a latent bug. Same applies to `stats`, though `HomeSessionExpired` works around it by creating a fresh `HomeState.initial()`.

   Fix when `error` display is added: use a sentinel value or a dedicated `clearError()` method.

### Positive Notes

- The service layer follows the ProfileModule pattern faithfully — constructor injection, pure Dart, no `App.shared` inside the service.
- The `HomeAuthenticated` event (not in the original plan) is a good addition — it handles login-while-on-HomeScreen, reloading data for the newly authenticated user.
- Widget migrations are clean: old providers (`suggestionsFutureProvider`, `userStatsFutureProvider`) are fully removed, no dangling references.
- `LogoutNotifier` → `UserNotifier.sessionExpiredStream` refactoring is solid: the guard in `clearSession()` prevents duplicate events, and the `_sessionExpiredSubject` is properly closed in `dispose()`.
- L10n keys for stats labels are correctly added to both EN and RU ARBs and generated files.
- `App.shared.logoutNotifier` field is cleanly removed with no remaining references anywhere in the codebase.
