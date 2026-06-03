# Plan: Add 10 s timeout to `UserApi.fetchSuggestions` and `StatsApi.fetchStats`

## Context
Prevent the two home-screen unary gRPC calls from hanging indefinitely when `GrpcConnectionManager.connect()` reports `connected` before TCP is actually ready, by bounding each `await` with a 10 s timeout.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Add timeouts

- [x] **Task 1: Add 10 s timeout to `UserApi.fetchSuggestions`**
  Files: `lib/User/UserApi.dart`
  In `fetchSuggestions`, append `.timeout(const Duration(seconds: 10))` to the `await _breathSessionService.getSuggestions(...)` call (line 22). No import changes — `timeout()` is the `dart:async` `Future` extension, already available. On timeout the resulting `TimeoutException` propagates to the existing `catch (e)` in `HomeViewModel`, which resets `isSuggestionsLoading = false`.

- [x] **Task 2: Add 10 s timeout to `StatsApi.fetchStats`**
  Files: `lib/User/StatsApi.dart`
  In `fetchStats`, append `.timeout(const Duration(seconds: 10))` to the `await _statsService.getStats(...)` call (line 13). No import changes needed. On timeout the `TimeoutException` propagates to the existing `catch (e)` in `HomeViewModel`, which resets `isStatsLoading = false`.
