# Plan Review: Add 10 s timeout to `UserApi.fetchSuggestions` and `StatsApi.fetchStats`

**Plan reviewed:** `05-add-10-s-timeout-to-userapi-fetchsuggestions-and-statsapi-fetchstats.md`
**Risk Level:** 🟢 Low

## Context Gates
- **Architecture:** No `.ai-factory/ARCHITECTURE.md` boundary conflict — changes are confined to the `lib/User/` API layer, no module-boundary crossings. WARN: not applicable.
- **Rules:** No `.ai-factory/RULES.md` violations detected.
- **Roadmap:** Small reliability `fix`; no milestone linkage required.

## Verification of Plan Assumptions

All claims in the plan were checked against the codebase and are **accurate**:

- **File paths correct.** `lib/User/UserApi.dart` and `lib/User/StatsApi.dart` exist as described.
- **Line numbers exact.** `await _breathSessionService.getSuggestions(...)` is at `UserApi.dart:22`; `await _statsService.getStats(...)` is at `StatsApi.dart:13`. Both match the plan verbatim.
- **`.timeout()` availability correct.** It is the `dart:async` `Future` extension method, already in scope via the framework — no import change needed, as the plan states.
- **Exception propagation path verified.** `HomeService.fetchSuggestions`/`fetchStats` (`lib/HomeModule/HomeService.dart:35,43`) do **not** wrap the API call in a try/catch, so a `TimeoutException` propagates unchanged up to `HomeViewModel` (`HomeViewModel.dart:41` and `:55`), where the `catch (e)` blocks reset `isSuggestionsLoading`/`isStatsLoading` to `false` and set `error: e.toString()`. The plan's described recovery behavior is exactly what the code does.

## Observations (non-blocking)

1. **`Future.timeout` does not cancel the underlying gRPC call.** Dart's `.timeout()` only stops the caller from awaiting; the in-flight gRPC RPC keeps running in the background until it resolves or the channel tears down. For the stated goal — unblocking the home screen UI — this is fine. If true wire-level deadline propagation were desired, the idiomatic gRPC approach is `options: CallOptions(timeout: Duration(seconds: 10))` on the generated client call. Not required for this task; noting for awareness.

2. **"Logging: minimal" setting.** No new log statement is introduced, but the existing `catch (e)` already records `error: e.toString()` into state, so a timeout is observable. Consistent with the "minimal" setting — no action needed.

3. **Both call sites run via `Future.wait`/independent loads** and each has its own loading flag and catch, so a timeout on one will not affect the other. Confirmed.

## Positive Notes
- Minimal, surgical change scoped to exactly two lines.
- Correctly identifies that no import or downstream error-handling changes are needed.
- Recovery semantics (loading flag reset) are already in place and correctly relied upon.

PLAN_REVIEW_PASS
