# Code Review 2: Keep HomeScreen shimmer on network errors

**Scope:** `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart` (only changed source file)
**Plan:** `.ai-factory/plans/06-keep-homescreen-shimmer-on-network-errors.md`
**Build check:** `flutter analyze lib/.../HomeViewModel.dart` → **No issues found.**

---

## Summary

This pass re-reviews the file after the fixes for review-1. Both findings from review-1 are now resolved, and the change remains faithful to the plan. Compilation is clean.

## Resolution of prior findings

### review-1 #1 [Medium] — stale failed request re-arms a retry → **FIXED**
Per-loader generation tokens (`_suggestionsLoadGeneration` / `_statsLoadGeneration`) were added. Each loader does `final gen = ++_xxxLoadGeneration;` at entry and bails with `if (gen != _xxxLoadGeneration) return;` after the `await` in **both** the success and `catch` paths. Trace: with overlapping loads A (gen 1) and B (gen 2), `_generation == 2`; when A's awaited call resolves, `1 != 2` → A returns without resetting the counter, mutating state, or arming a retry. Only the newest invocation owns the outcome, so the shimmer can no longer flash back over loaded content and no orphan retry is scheduled. Correct and minimal.

### review-1 #2 [Low] — pending timers not cancelled on logout → **FIXED**
The `HomeSessionExpired` branch now cancels both `_suggestionsRetryTimer` and `_statsRetryTimer` before resetting to `HomeState.initial()`, so an armed backoff timer no longer fires after logout.

## Verification of the generation guard (no new issues introduced)

- **Loading never gets stuck `true`:** the newest generation always owns the terminal state — it either resolves loading to `false` (success / non-network error) or intentionally holds it `true` and arms a retry that itself runs as the next newest generation. Superseded calls bail without touching loading, which the superseding call already manages.
- **Retry chain:** a fired retry timer calls the loader, which bumps the generation and becomes the owner; the backoff counter still resets only on a real success. Indefinite capped retry behavior is preserved.
- **Shimmer gating** (`!isGuest && isXxxLoading` in `StatsCard` / `SuggestionsCard`) is unchanged and still honored.

## Note (non-blocking, informational)

`HomeSessionExpired` cancels the timers but does not bump the generation counters. If a unary fetch is already in flight when logout occurs, that fetch can still complete and write its result into the freshly-reset state (e.g. `suggestions`). This is harmless in practice: the reset sets `isGuest = true`, both cards are gated on `!isGuest`, so nothing renders, and a subsequent `HomeAuthenticated → _loadInitialData()` overwrites it on re-login. Bumping both generations in the `HomeSessionExpired` branch would close even this cosmetic gap, but it is not required for correctness.

## Verdict

Both prior findings are correctly resolved, the generation-token approach introduces no new races, and the file analyzes cleanly. No blocking issues.

REVIEW_PASS
