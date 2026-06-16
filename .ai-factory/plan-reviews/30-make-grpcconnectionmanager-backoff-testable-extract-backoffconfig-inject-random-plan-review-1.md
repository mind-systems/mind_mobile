# Plan Review: Make `GrpcConnectionManager` backoff testable

**Plan:** `30-make-grpcconnectionmanager-backoff-testable-extract-backoffconfig-inject-random.md`
**Files Reviewed:** 3 (plan + `GrpcConnectionManager.dart`, `App.dart`, cross-checked `ROADMAP_TESTS.md`, `RULES.md`)
**Risk Level:** 🟢 Low

## Verification against the codebase

Every concrete claim in the plan was checked against the current source and holds:

- **Lines 32–33** are exactly `static const Duration _initialDelay = Duration(seconds: 1);` / `_maxDelay = Duration(seconds: 30);`. The proposed `BackoffConfig` defaults match these values 1:1 — no behavior change. ✓
- **`_nextDelay()`** (lines 116–128) uses `_initialDelay` once (line 118), `_maxDelay` twice (line 120 clamp branch + line 126 `.clamp(0, _maxDelay.inMilliseconds)`), and `math.Random().nextDouble()` once (line 122). The plan correctly enumerates all four substitution points. ✓
- **`_scheduleReconnectInternal()`** (line 138) has the inline `Timer(delay, () { if (_isAuthenticated) connect(); })` the plan targets. ✓
- **`dart:math as math`** stays required (`math.min`, `math.pow` remain in `_nextDelay`); `dart:async` already imported for `Timer`. ✓
- **`App.dart:200`** constructs `GrpcConnectionManager` with exactly the three required streams and no other args. Adding optional named params keeps this call site source-compatible — no edit needed. ✓ The plan correctly scopes Task 3 as verification-only.
- **`Timer.new`** is a valid tear-off matching `typedef TimerFactory = Timer Function(Duration, void Function())`. ✓

## Context Gates

- **RULES.md** — WARN-clean. The rule "All dependencies must be injected via constructor" is *reinforced* by this plan (random + timer become injectable). No App.dart state added (App.dart untouched). No module-service statefulness concerns (this is Core infra, not a module Service). ✓
- **ARCHITECTURE.md** — no boundary conflict; `lib/Core/Grpc/` is the correct home and `BackoffConfig.dart` stays pure Dart per the plan. ✓
- **ROADMAP linkage** — the downstream milestone **`GrpcConnectionManager` backoff tests** exists in `ROADMAP_TESTS.md:33` and names this refactor as its prerequisite (`BackoffConfig(initialDelay: …, maxDelay: …, random: Random(0))`). The plan's scope note aligns exactly. ✓

## Observations (non-blocking)

1. **Testing seam is adequate but implicit.** The downstream test plan (`ROADMAP_TESTS.md:33`) is phrased as if it calls `_nextDelay()` and inspects `_reconnectAttempt` / `_scheduleReconnectInternal()` directly — all of which are private and *not* exposed by this refactor. The refactor still enables those tests through the **public path**: a fake `TimerFactory` captures the `Duration` argument, driven via the public `scheduleReconnect()`, with `_isAuthenticated` set by pushing `AuthenticatedState` through `authStream`. This works and is the intended seam, so no change is required here — but the downstream test author should know the assertions must go through the public API + injected `TimerFactory`, not direct private access. Worth a one-line hint in the downstream plan rather than this one.

2. **Exponent cap `6` stays hardcoded** in `_nextDelay`. The downstream test "attempt 6 == attempt 7" depends on it. Keeping it out of `BackoffConfig` is the right minimal scope; just noting the coupling is intentional and fine.

## Positive Notes

- Defaults-preserving design guarantees zero production behavior change, exactly as the plan claims.
- Injecting `TimerFactory` (not just `Random`) is the key insight that makes delay *observable* without `fakeAsync` flakiness — good call.
- Clean dependency ordering (Task 1 → 2 → 3) with explicit `depends on` markers.
- Correctly resists scope creep: no test files, no App.dart edits, no exponent-cap extraction.

No missing steps, wrong assumptions, incorrect paths, or API misuse found.

PLAN_REVIEW_PASS
