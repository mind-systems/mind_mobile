# Code Review: Make `GrpcConnectionManager` backoff testable

**Plan:** `30-make-grpcconnectionmanager-backoff-testable-extract-backoffconfig-inject-random.md`
**Files reviewed (in full):** `lib/Core/Grpc/BackoffConfig.dart` (new), `lib/Core/Grpc/GrpcConnectionManager.dart` (modified), `lib/Core/App.dart:200` (call site).
**Analyzer:** `flutter analyze` on both changed Dart files → *No issues found.*
**Risk level:** 🟢 Low

## Summary

The refactor is correct and behavior-preserving. `BackoffConfig` and an injectable `TimerFactory` are added as optional constructor parameters that default to the exact prior production values, and all four substitution points in `_nextDelay()` plus the `Timer` construction in `_scheduleReconnectInternal()` were updated as specified. No production behavior change.

## Correctness verification

- **Defaults match old constants 1:1.** `BackoffConfig()` → `initialDelay = 1s`, `maxDelay = 30s`, identical to the removed `static const _initialDelay`/`_maxDelay`. Production constructs `GrpcConnectionManager` with no overrides, so the runtime values are unchanged. ✓
- **`Timer.new` ≡ inline `Timer(...)`.** The default `timerFactory = Timer.new` is a tear-off whose signature matches `typedef TimerFactory = Timer Function(Duration, void Function())`; analyzer confirms the type is satisfied and `_scheduleReconnectInternal` calls it identically. ✓
- **`_nextDelay()` math unchanged.** Exponent cap `math.min(_reconnectAttempt, 6)`, `math.pow(2, exp)`, ±25% jitter, `_reconnectAttempt++`, and the lower/upper `.clamp(0, maxDelay)` are all preserved; only the operands are now read from `_backoffConfig`. ✓
- **Random injection is sound.** Production now reuses a single `Random()` instance across `_nextDelay()` calls instead of allocating `math.Random()` per call. This is statistically equivalent (arguably better) for jitter and introduces no determinism regression; tests pass `Random(0)` for reproducible output. Dart is single-threaded per isolate, so the shared instance has no concurrency hazard. ✓
- **Call site untouched and source-compatible.** `App.dart:200` passes only the three required streams; the new params are optional. No edit needed, none made. ✓
- **`dart:math as math` still required** (`math.min`, `math.pow`) and retained; `dart:async`/`Timer` already imported. `BackoffConfig.dart` is pure Dart (no Flutter imports). ✓
- **No leaks introduced.** `_reconnectTimer?.cancel()` / `_reconnectTimer = null` lifecycle in `disconnect()`/`dispose()` is unchanged; the injected factory still returns a `Timer` that is tracked and cancelled normally. ✓

## Observations (non-blocking)

1. **Redundant `late` on the two new fields.** `_backoffConfig` and `_timerFactory` are declared `late final` (lines 33–34) but are assigned in the constructor initializer list (lines 50–51), where the values are already available. Plain `final` would be more idiomatic and matches the plan's wording ("Add two final instance fields"). The `late` is only genuinely needed for the subscription fields assigned in the body. This compiles cleanly and behaves identically — purely a minor style nit, not a defect.

2. **Private-member test seam (informational, downstream concern).** The downstream test milestone (`ROADMAP_TESTS.md:33`) is phrased as if it inspects `_nextDelay()` / `_reconnectAttempt` directly. Those remain private; the intended seam is the public `scheduleReconnect()` driven with `_isAuthenticated` set via `authStream`, capturing the scheduled `Duration` through a fake `TimerFactory`. This refactor enables exactly that — no change required here.

No bugs, security issues, or correctness problems found.

REVIEW_PASS
