# Plan: Keep HomeScreen shimmer on network errors

## Context
On a network/timeout error the HomeScreen suggestion and stats areas currently collapse because both catch blocks unconditionally reset their loading flags. The goal is to keep the shimmer visible on transient network errors and recover automatically once the backend is reachable again.

Roadmap item: `.ai-factory/ROADMAP.md` line 29 — "Keep HomeScreen shimmer on network errors". Prerequisite: note 69 (10 s timeout on `UserApi.fetchSuggestions` / `StatsApi.fetchStats`, already merged). Spec: `.ai-factory/notes/70-home-shimmer-keep-on-network-error.md`.

### Recovery design (addresses plan-review-1)
The original plan relied solely on `HomeGrpcReconnected → _loadInitialData()` for recovery. Plan review 1 correctly identified this is **insufficient for the exact errors `_isNetworkError` targets**:

- `HomeService.observeChanges()` derives `HomeGrpcReconnected` from a pairwise `connected`-transition of `connectionStateStream`, driven entirely by `GrpcConnectionManager`.
- `GrpcConnectionManager` only flips to `disconnected` on full connectivity loss (`ConnectivityResult.none`), logout, or an explicit transport-stream `scheduleReconnect()`. Its `connect()` performs no handshake/health check and skips entirely when `currentState == connected`.
- A **unary** `getSuggestions` / `getStats` that throws `TimeoutException` or `GrpcError.unavailable` **while connectivity is still reported present** (backend down/restarting, slow backend hitting the 10 s timeout, captive Wi-Fi/DNS failure) does **not** change connection state. So `HomeGrpcReconnected` never fires and the shimmer would stay forever — worse than today's collapse.

Therefore recovery must not depend on the connection-state machinery. This plan adds a **self-contained capped-backoff retry inside the ViewModel** (no changes to `GrpcConnectionManager` or shared streams — disconnecting the channel on a single unary failure would tear down biometric/other streams and is out of scope). It also makes `HomeAppResumed` retry both areas so foreground/background is an additional recovery lever, and fixes the pre-existing asymmetry where resume only reloaded suggestions.

All changes remain in **one file**: `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Imports and error classification

- [x] **Task 1: Add grpc import and `_isNetworkError` helper**
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`
  Add `import 'package:grpc/grpc.dart';` (unaliased — matches existing usage in `lib/Core/Grpc/` and `lib/User/AuthApi.dart`; do NOT alias). `import 'dart:async';` is already present at line 1 (provides both `TimeoutException` and `Timer`) — do not duplicate it. Add a private helper to `HomeViewModel`:
  ```dart
  bool _isNetworkError(Object e) =>
      e is TimeoutException ||
      (e is GrpcError && e.code == StatusCode.unavailable);
  ```
  **Note (review minor issue):** `StatusCode.cancelled` is intentionally **dropped** from the predicate. `cancelled` is typically client-initiated (request superseded, Notifier disposed), not a transient network fault; classifying it as a network error would keep the shimmer up and arm a pointless retry. Keep only the genuine transient-network signals: `TimeoutException` and `unavailable`.

### Phase 2: Recovery infrastructure

- [x] **Task 2: Add capped-backoff retry fields, delay helper, and dispose cleanup** (depends on Task 1)
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`
  Add per-loader retry timers and attempt counters as instance fields, plus retry-delay constants:
  ```dart
  Timer? _suggestionsRetryTimer;
  Timer? _statsRetryTimer;
  int _suggestionsRetryAttempt = 0;
  int _statsRetryAttempt = 0;

  static const Duration _retryBaseDelay = Duration(seconds: 2);
  static const Duration _retryMaxDelay = Duration(seconds: 30);
  ```
  Add a delay helper that doubles per attempt and clamps at the max (keeps retrying at the cap indefinitely while the screen is mounted — the shimmer should persist until the load eventually succeeds):
  ```dart
  Duration _retryDelay(int attempt) {
    final factor = 1 << attempt.clamp(0, 4); // 2,4,8,16,32 → clamped
    final ms = (_retryBaseDelay.inMilliseconds * factor)
        .clamp(0, _retryMaxDelay.inMilliseconds);
    return Duration(milliseconds: ms);
  }
  ```
  In `build()`, register cleanup so the timers don't fire after disposal. The existing `ref.onDispose(() => subscription.cancel());` cancels the stream subscription; add timer cancellation as well (either a second `ref.onDispose` or extend the existing callback):
  ```dart
  ref.onDispose(() {
    _suggestionsRetryTimer?.cancel();
    _statsRetryTimer?.cancel();
  });
  ```

### Phase 3: Wire loaders and events to the recovery path

- [x] **Task 3: Update both loaders to keep shimmer and self-retry on network errors** (depends on Task 2)
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`
  Rewrite `_loadSuggestions` so it (a) cancels any pending retry at the start to dedupe against reconnect/resume/timer-driven invocations, (b) resets the attempt counter on success, and (c) on a network error keeps `isSuggestionsLoading = true` and arms the next backoff retry instead of relying on `HomeGrpcReconnected`:
  ```dart
  Future<void> _loadSuggestions() async {
    _suggestionsRetryTimer?.cancel();
    state = state.copyWith(isSuggestionsLoading: true);
    try {
      final suggestions = await service.fetchSuggestions();
      _suggestionsRetryAttempt = 0;
      state = state.copyWith(suggestions: suggestions, isSuggestionsLoading: false);
    } catch (e) {
      if (_isNetworkError(e)) {
        // Keep isSuggestionsLoading = true so the shimmer persists, and retry —
        // unary failures don't trigger HomeGrpcReconnected while connectivity is intact.
        _suggestionsRetryTimer =
            Timer(_retryDelay(_suggestionsRetryAttempt++), _loadSuggestions);
        return;
      }
      state = state.copyWith(isSuggestionsLoading: false, error: e.toString());
    }
  }
  ```
  Apply the symmetric change to `_loadStats` (preserve its existing `stats != null` / null branch on success, reset `_statsRetryAttempt = 0` on a successful fetch, and use `_statsRetryTimer` / `_statsRetryAttempt`):
  ```dart
  Future<void> _loadStats() async {
    _statsRetryTimer?.cancel();
    state = state.copyWith(isStatsLoading: true);
    try {
      final stats = await service.fetchStats();
      _statsRetryAttempt = 0;
      if (stats != null) {
        state = state.copyWith(stats: stats, isStatsLoading: false);
      } else {
        state = state.copyWith(isStatsLoading: false);
      }
    } catch (e) {
      if (_isNetworkError(e)) {
        // Keep isStatsLoading = true → shimmer persists; retry with backoff.
        _statsRetryTimer = Timer(_retryDelay(_statsRetryAttempt++), _loadStats);
        return;
      }
      state = state.copyWith(isStatsLoading: false, error: e.toString());
    }
  }
  ```
  Non-network errors (e.g. `PERMISSION_DENIED`) still collapse the areas as before — good separation preserved.

- [x] **Task 4: Make app-resume recover both areas** (depends on Task 3)
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`
  In `_onEvent`, the `HomeAppResumed` branch currently calls `_loadSuggestions()` only. Add `_loadStats()` so foreground/background recovers the stats shimmer too, removing the asymmetric dead-end flagged in the review (resume could otherwise recover suggestions but leave stats stuck):
  ```dart
  case HomeAppResumed _:
    _loadSuggestions();
    _loadStats();
  ```
  Leave the other branches (`StatsInvalidated`, `HomeSessionExpired`, `HomeAuthenticated`, `HomeGrpcReconnected`) unchanged — `HomeGrpcReconnected → _loadInitialData()` still works as a recovery path for the genuine connectivity-loss case, now complemented by the in-ViewModel retry for the unary-failure case.

## Verification
1. Server unreachable (connectivity intact) → both shimmers persist past the 10 s timeout, then a backoff retry fires (~2 s, 4 s, … capped at 30 s) and keeps retrying; no collapse.
2. Server comes back → the next retry (or `HomeGrpcReconnected`, or app resume) succeeds → shimmer replaced by content; attempt counters reset.
3. Device connectivity fully lost then restored → `HomeGrpcReconnected → _loadInitialData()` retries as before.
4. App backgrounded/foregrounded while stuck → `HomeAppResumed` reloads both suggestions and stats.
5. Server returns a real error (e.g. `PERMISSION_DENIED`) → areas collapse normally (not treated as a network error, no retry armed).
6. Screen disposed mid-retry → pending timers cancelled, no state mutation after dispose.
