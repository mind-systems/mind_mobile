# Code Review: Keep HomeScreen shimmer on network errors

**Scope:** `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart` (only changed source file)
**Plan:** `.ai-factory/plans/06-keep-homescreen-shimmer-on-network-errors.md`
**Build check:** `flutter analyze lib/.../HomeViewModel.dart` → **No issues found.**

---

## Summary

The implementation matches the plan task-for-task: grpc import added, `_isNetworkError` predicate (Timeout + `unavailable`, `cancelled` correctly dropped), capped-backoff retry fields + `_retryDelay` helper, timer cancellation in `ref.onDispose`, both loaders re-arm a retry on network error while keeping their loading flag `true`, and `HomeAppResumed` now reloads both areas. The shimmer-gating contract (`!isGuest && isXxxLoading` in `StatsCard`/`SuggestionsCard`) is preserved, so holding the flag keeps the shimmer as intended. Compilation is clean — including the `1 << attempt.clamp(0, 4)` / `Duration(milliseconds: ...clamp(...))` lines, since Dart special-cases `int.clamp(int, int)` to return `int`.

One genuine correctness issue (race condition) and a couple of low-severity notes follow.

---

## Findings

### 1. [Medium] Stale failed request re-arms a retry after a successful load → shimmer flashes back

`_loadSuggestions` / `_loadStats` have **no in-flight guard**, and several event sources invoke them concurrently: `StatsInvalidated`, `HomeAuthenticated` (`_loadInitialData`), `HomeAppResumed`, `HomeGrpcReconnected` (`_loadInitialData`), the retry timer itself, and the initial `build()` microtask. Because each loader `await`s a network call (up to the 10 s timeout), two invocations can be in flight at once.

The retry timer is armed **only inside the `catch` block, after the `await` completes** — `_xxxRetryTimer?.cancel()` at the top of the method cannot cancel a retry that a *concurrent* call has not yet scheduled. So:

- Load A fails with a network error and Load B succeeds (in either completion order).
- B sets `stats`/`suggestions`, `isXxxLoading = false`, resets the attempt counter, and shows content.
- A then enters its `catch`, sees `_isNetworkError(e) == true`, and **schedules a fresh retry timer** even though the area is already loaded.
- After the delay that timer fires → the loader runs again → `isXxxLoading = true` → the **shimmer briefly reappears over already-rendered content**, plus a redundant network call.

It is self-terminating once the network is stable (the next fetch succeeds), so it is a transient UX glitch + spurious request rather than an infinite loop — but it is a real regression versus the old code, which never re-armed anything. Concrete trigger: backgrounding/foregrounding the app (`HomeAppResumed`) while an initial/retry fetch is still in flight, or `HomeGrpcReconnected` arriving mid-retry.

**Suggested fix:** add a per-loader generation token (or in-flight flag) and ignore the result/skip re-arming when a newer invocation has superseded this one. Sketch:

```dart
int _statsLoadGeneration = 0;

Future<void> _loadStats() async {
  _statsRetryTimer?.cancel();
  final gen = ++_statsLoadGeneration;
  state = state.copyWith(isStatsLoading: true);
  try {
    final stats = await service.fetchStats();
    if (gen != _statsLoadGeneration) return;        // superseded
    _statsRetryAttempt = 0;
    ...
  } catch (e) {
    if (gen != _statsLoadGeneration) return;        // a newer load owns the state
    if (_isNetworkError(e)) {
      _statsRetryTimer = Timer(_retryDelay(_statsRetryAttempt++), _loadStats);
      return;
    }
    state = state.copyWith(isStatsLoading: false, error: e.toString());
  }
}
```

(Same for `_loadSuggestions`.) This also removes the redundant double-fetch that already existed pre-change but was harmless before.

---

### 2. [Low] Pending retry timers are not cancelled on `HomeSessionExpired`

`HomeSessionExpired` resets state to `HomeState.initial()` but leaves any armed retry timer running. On logout, a pending `_statsRetryTimer` / `_suggestionsRetryTimer` will still fire and call the loader. It is effectively harmless — `HomeService.fetchSuggestions`/`fetchStats` short-circuit to `[]`/`null` for guests, and the shimmer gate (`!isGuest`) is false after reset — so it degrades to a no-op pair of state writes. Still, cancelling both timers in the `HomeSessionExpired` branch would be cleaner and avoids a stray post-logout state mutation. Not blocking.

---

### 3. [Note / pre-existing] `error` is write-only and sticky

Both catch blocks still write `error: e.toString()`, but no HomeScreen widget reads `state.error`, and `copyWith(error: error ?? this.error)` cannot clear it back to `null` once set. This is pre-existing (already flagged in plan-review-1) and out of scope for this change — noting only that the network-error path now correctly avoids touching it.

---

## Verdict

The change is functionally correct for the primary scenario (server down / unary timeout → shimmer persists and recovers via backoff or resume) and compiles cleanly. Finding #1 is a real race that can flash the shimmer back over loaded content and issue redundant fetches when loads overlap; recommend addressing it with an in-flight/generation guard before merge. Findings #2 and #3 are optional cleanups.
