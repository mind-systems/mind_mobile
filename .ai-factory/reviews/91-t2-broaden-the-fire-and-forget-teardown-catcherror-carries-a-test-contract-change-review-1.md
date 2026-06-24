# Code Review: T2 · Broaden the fire-and-forget teardown `.catchError`

**Branch:** `phase-55-serialize-bci-lifecycle`
**Scope reviewed:** `lib/Bci/NeiryBciProvider.dart`, `test/Bci/neiry_bci_provider_full_teardown_test.dart`
**Result:** ✅ Correct, scoped, verified green.

## Changes

1. **`lib/Bci/NeiryBciProvider.dart:462-477`** — The fire-and-forget teardown command's `.catchError(...)` dropped its `test: (Object e) => e is QueueClosedException` filter and now catches **all** errors, branching inside the callback: a `QueueClosedException` is swallowed silently (dispose-races-drop semantics preserved), any other error is logged via `logPrint('NeiryBciProvider: unexpected drop teardown error: $e')` and swallowed.
2. **`test/Bci/neiry_bci_provider_full_teardown_test.dart:618-678`** — The B2 characterization test's assertion was inverted from "StateError surfaces as unhandled async error" (`asyncErrors isNotEmpty` + `is StateError`) to "logged and swallowed" (`asyncErrors isEmpty`). Test name + doc comments updated to match.

## Correctness analysis

- **Subtype direction is correct.** `QueueClosedException extends StateError` (`lib/Bci/SerialCommandQueue.dart:9`). The injected test error is a *plain* `StateError`. A plain `StateError` is **not** a `QueueClosedException`, so `e is! QueueClosedException` evaluates `true` and the error is logged — exactly as intended. The subclass relationship does not cause a real teardown error to be misclassified as a queue-drop and silently swallowed. (The reverse — a real `QueueClosedException` being logged — also cannot happen, since the `is!` guard correctly excludes it.)
- **`catchError` semantics are sound.** `_queue.enqueue(...)` returns `Future<void>`; the `(Object e) {}` callback returns void, which resolves the chained future to `void` — no unhandled rejection. Removing `test:` is the right mechanism to broaden coverage; previously non-`QueueClosed` errors propagated out and escaped the zone (which is exactly what the old test pinned).
- **Escape paths covered.** The unguarded fan-in cancel chain (`:434-443`) and the `_resetLocatorSession()` recreate in the `finally` (`:460`) both reject the enqueue future; both are now caught. The per-step inner `try/catch` blocks (stopStream `:431`, classifier dispose `:446-450`, device disconnect/dispose `:453-458`) are untouched, so their existing localized logging still fires first; this broadened handler is purely a top-level safety net.
- **Dispose-races-drop leak unchanged.** The `QueueClosedException` branch is a no-op, identical to the prior `(Object e) {}` swallow under `test:`. The knowingly-accepted leak documented in the comment block is preserved; no queue CONSTRAINT or dispose ordering was altered.
- **Stale comment fixed.** The previously misleading trailing line ("a real teardown-body error still surfaces") was replaced with an accurate description of the log-and-swallow net — the plan-review's minor concern #1 was addressed.
- **Imports present.** `logPrint` (via `../Logger.dart:33`) and `QueueClosedException` (via `SerialCommandQueue.dart:18`) are already in scope; no new imports needed.

## Test-contract change

- The inversion is the **deliberate** contract change called out in the milestone, not a green→green regression. The `isEmpty` assertion is placed after the existing trailing `Future.delayed(Duration.zero)` pumps, so it runs once the teardown microtask has fully settled — robust.
- The surrounding L1 invariants (`createdCount == 2`, `l0.disposeCount == 1`, `liveCount == 1`, `assertNoOrphan()`) and post-test `closeControllers()` cleanup are retained; recreate is still asserted to be reached. The "remaining 9 fan-in subs + classifierSet never cancelled" comment (`:679-681`) remains accurate — the throw on the first cancel still short-circuits the rest.
- Grep confirmed no other test in `test/Bci/` depends on the old "surfaces as unhandled async error" contract, so the flip is correctly isolated to this one assertion.

## Runtime verification

- `flutter test test/Bci/neiry_bci_provider_full_teardown_test.dart` → **6/6 pass**; the throwing-cancel case logs `NeiryBciProvider: unexpected drop teardown error: Bad state: ThrowOnCancelStream: cancel error [cancelFanIn]` and produces no unhandled async error.
- `flutter test test/Bci/` → **63/63 pass** (full B1/B2 + locator/race suites green).

## Findings

None.

REVIEW_PASS
