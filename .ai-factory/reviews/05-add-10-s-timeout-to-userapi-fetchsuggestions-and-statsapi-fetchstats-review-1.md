# Code Review: Add 10 s timeout to `UserApi.fetchSuggestions` and `StatsApi.fetchStats`

**Plan:** `05-add-10-s-timeout-to-userapi-fetchsuggestions-and-statsapi-fetchstats.md`
**Scope of changes:** `lib/User/UserApi.dart`, `lib/User/StatsApi.dart` (plus plan/review metadata files)

## Changes reviewed

Both edits are single-line and match the plan verbatim:

- `UserApi.fetchSuggestions` — `.timeout(const Duration(seconds: 10))` appended to the `getSuggestions(...)` await.
- `StatsApi.fetchStats` — `.timeout(const Duration(seconds: 10))` appended to the `getStats(...)` await.

## Correctness analysis

- **`.timeout()` is valid on the call result.** The generated gRPC clients return `ResponseFuture<T>`, which implements `Future<T>`, so the `dart:async` `Future.timeout` extension applies. No import change needed — confirmed.
- **Exception propagation path verified end-to-end.** On timeout, `Future.timeout` (with no `onTimeout` handler) throws `TimeoutException`. `HomeService.fetchSuggestions`/`fetchStats` (`lib/HomeModule/HomeService.dart`) do not wrap the API call in try/catch, so the exception propagates unchanged to `HomeViewModel._loadSuggestions`/`_loadStats` (`lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart:35-59`). Both methods have a `catch (e)` that resets `isSuggestionsLoading`/`isStatsLoading` to `false` and records `error: e.toString()`. The documented recovery behavior is exactly what the code does.
- **No type mismatch, no breaking signature change.** Return types of both API methods are unchanged.
- **No race-condition or concurrency regression.** The two loads run independently with separate loading flags and separate catch blocks; a timeout on one cannot affect the other.

## Observations (non-blocking)

1. **`Future.timeout` does not cancel the underlying RPC.** The in-flight gRPC call keeps running in the background until it resolves or the channel tears down; `.timeout()` only stops the caller from awaiting. This is acceptable for the stated goal (unblocking the home screen UI) and is consistent with the interim-fix framing in the spec note. If wire-level deadline propagation is later desired, the idiomatic approach is `options: CallOptions(timeout: ...)` on the generated client call.
2. **Interim UX is as documented.** On timeout the shimmer collapses rather than persisting; note 70 is the planned follow-up. No action here.

No bugs, security issues, or correctness problems found.

REVIEW_PASS
