# Plan Review 2: Keep HomeScreen shimmer on network errors

**Plan:** `.ai-factory/plans/06-keep-homescreen-shimmer-on-network-errors.md`
**Files in scope:** `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`
**Risk Level:** 🟢 Low — the v2 plan directly resolves every blocking and minor issue raised in plan-review-1. Remaining items are non-blocking observations.

---

## Code Review Summary

**Files Reviewed:** 1 target file (`HomeViewModel.dart`) + 5 supporting files re-verified (`HomeService.dart`, `IHomeService.dart`, `HomeState.dart`, `HomeDTOs.dart`, `UserApi.dart`/`StatsApi.dart`, `SuggestionsCard.dart`/`StatsCard.dart`)
**Risk Level:** 🟢 Low

### Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** Change stays entirely inside the ViewModel (presentation/module boundary). No domain-model leakage, no new streams, no Service mutation, no DI changes. **PASS.**
- **Rules (`.ai-factory/RULES.md`):** The "Module Services stay stateless / `observeChanges()` returns a derived stream" rule is untouched — all new state (timers, counters) lives in the ViewModel, which is the correct place for presentation-side recovery state. **PASS.**
- **Roadmap (`.ai-factory/ROADMAP.md`):** The plan now explicitly cites the roadmap item (line 29 — "Keep HomeScreen shimmer on network errors") and note 70, resolving the plan-review-1 traceability WARN. **PASS.**
- **skill-context (`.ai-factory/skill-context/aif-review/SKILL.md`):** absent — no project-specific review overrides to apply.

---

## How plan-review-1 issues were resolved

- ✅ **Critical (recovery never fires for targeted errors):** Resolved. The plan no longer relies on `HomeGrpcReconnected`. It adds a self-contained capped-backoff retry inside the ViewModel, armed directly from each loader's network-error branch. The "Recovery design" section (lines 8–17) correctly re-states why the connection-state machinery cannot fire for a unary `TimeoutException`/`unavailable` while connectivity is intact. This is the right scope choice — disconnecting the shared channel on a single unary failure would tear down biometric/other streams.
- ✅ **Secondary (stats can't recover on resume):** Resolved. Task 4 adds `_loadStats()` to the `HomeAppResumed` branch alongside `_loadSuggestions()`, removing the asymmetric dead-end. `HomeAppResumed` exists in `HomeDTOs.dart` (line 34) and `HomeService` maps `resumeStream` to it (line 69) — confirmed.
- ✅ **Minor (`StatusCode.cancelled`):** Resolved. The predicate now intentionally drops `cancelled` (deviating from note 70's original snippet) with a clear justification comment. Keeping only `TimeoutException` + `unavailable` is the correct call — a client-initiated cancel should not arm a retry.

---

## Verified assumptions (correct)

- ✅ **Error propagation intact.** `UserApi.fetchSuggestions` / `StatsApi.fetchStats` call `.timeout(const Duration(seconds: 10))` with no `onTimeout` (so a real `TimeoutException` is thrown) and do not wrap gRPC errors. `HomeService.fetchSuggestions`/`fetchStats` re-throw transparently. Original `TimeoutException` / `GrpcError` types reach the ViewModel catch — the `is`-checks work.
- ✅ **Imports.** `import 'package:grpc/grpc.dart';` unaliased matches existing usage in `lib/Core/Grpc/` and `lib/User/AuthApi.dart`. `dart:async` is already on line 1 and provides both `TimeoutException` and `Timer` — the plan correctly says not to duplicate it.
- ✅ **State shape.** `HomeState.copyWith` exposes `isSuggestionsLoading`, `isStatsLoading`, `error` exactly as the snippets assume. `_loadStats`' existing `stats != null` / null branch is preserved.
- ✅ **Shimmer gating.** `SuggestionsCard` (line 25) and `StatsCard` (line 24) render the shimmer purely on `!state.isGuest && state.isXxxLoading`. Keeping the flag `true` keeps the shimmer — mechanism confirmed.
- ✅ **Backoff math.** `1 << attempt.clamp(0,4)` → factor ∈ {1,2,4,8,16}; `2000ms × factor` → {2,4,8,16,32}s; `.clamp(0, 30000)` caps the 32 s case at 30 s. Sequence is 2 → 4 → 8 → 16 → 30 → 30 … as described. `int.clamp(int,int)` returns `int`, so `Duration(milliseconds: ms)` type-checks.
- ✅ **Attempt counter semantics.** Post-increment `_retryDelay(_attempt++)` uses the current value for the delay then increments; reset to 0 on success. Correct.
- ✅ **Dedup on start + dispose cleanup.** Cancelling the pending timer at the top of each loader correctly de-dupes the timer-vs-event case (e.g. a `HomeGrpcReconnected`/resume that arrives while a retry is pending cancels the pending timer). `ref.onDispose` cancellation prevents fired timers from mutating state post-dispose. Riverpod allows multiple `onDispose` registrations.
- ✅ **`switch` syntax.** Multi-statement case bodies without braces are valid Dart switch-statement syntax (no fall-through); matches the existing style in `_onEvent`.

---

## Non-blocking observations

1. **In-flight fetch can still mutate state after dispose (pre-existing).** Verification item 6 claims "pending timers cancelled, no state mutation after dispose." Timer cancellation only stops *not-yet-fired* retries. If disposal happens while an `await service.fetchSuggestions()` is already in flight (the timer already fired), the subsequent `state = state.copyWith(...)` runs on a disposed Notifier and throws a `StateError`. This is **pre-existing** behavior (the current code already awaits and assigns `state` with no mounted guard from `Future.microtask` and event handlers), so the plan does not make it worse — but the verification claim slightly overstates the guarantee. Optional hardening: guard `state =` assignments behind a mounted/disposed check, or wrap in a disposed-state catch. Low priority; out of the plan's stated scope.

2. **No guard against concurrent in-flight loads.** Two near-simultaneous invocations (e.g. a fired retry timer and a resume/reconnect event whose cancel-on-start missed the window because the fetch was already past the timer callback) can run two overlapping fetches. The start-cancel handles the common case cleanly; the residual window is bounded by the fetch duration and at worst yields an occasional duplicate retry, not unbounded growth (each new `_loadXxx` overwrites/cancels the timer field). Acceptable for this fix; flag only so it is a known property.

3. **Stats now re-fetches and flashes the shimmer on every app resume.** Adding `_loadStats()` to `HomeAppResumed` is correct for recovery symmetry, but it means a healthy foreground (no error) now sets `isStatsLoading = true` and refetches stats on each resume, briefly re-showing the stats shimmer. Suggestions already behaved this way; stats now matches. Intended per the plan, but worth confirming the brief shimmer flash on resume is acceptable UX (it will be brief on a fast fetch).

4. **Attempt counter not reset on a non-network error.** A non-network error (`PERMISSION_DENIED`) collapses the area but does not reset `_xxxRetryAttempt`. If a network error later follows in the same ViewModel lifetime, the first retry uses a longer delay than 2 s. Cosmetic only; the counter is reset on the next success. Optional: reset the counter in the non-network catch branch for cleanliness.

---

## Positive Notes

- The recovery redesign is the right architectural choice: keeping retry state in the ViewModel rather than touching `GrpcConnectionManager`/shared streams avoids tearing down unrelated biometric streams and keeps the Service stateless per project rules.
- The plan demonstrates careful re-verification of plan-review-1's findings rather than just asserting fixes — the connection-state analysis (lines 9–15) is accurate against `GrpcConnectionManager`/`HomeService.observeChanges()`.
- Backoff is capped but unbounded in count by design (shimmer persists until success), which matches the feature intent ("shimmer while disconnected") far better than a fixed retry budget that would eventually collapse.
- Task dependency ordering (1 → 2 → 3 → 4) is correct, and all changes are confined to a single file with no migration, proto, or DI impact.
- The `StatusCode.cancelled` justification is documented inline, so the deviation from note 70 won't read as an accidental omission during implementation.

---

## Verdict

The v2 plan resolves the critical recovery gap, the stats-on-resume asymmetry, and the `cancelled` classification concern from plan-review-1. Assumptions about imports, error propagation, state shape, shimmer gating, and backoff math all check out against the codebase. Remaining items are non-blocking observations (one pre-existing dispose-race, minor concurrency/UX/counter notes). Solid to implement.

PLAN_REVIEW_PASS
