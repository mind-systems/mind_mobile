# Code Review: Make `BiometricBatcher` testable — inject flush interval + batch-size cap

## Scope
Single code change: `lib/Biometrics/BiometricBatcher.dart`. The other staged files are plan/plan-review artifacts (no code).

## What changed
- The two `static const` fields (`_maxBatchSize = 25`, `_flushInterval = Duration(milliseconds: 250)`) were converted to `final` instance fields.
- Two optional named constructor parameters `flushInterval` and `maxBatchSize` were added with defaults equal to the previous constants, assigned via the initializer list.

## Verification

- **No behavior change.** Defaults (`const Duration(milliseconds: 250)`, `25`) exactly match the removed constants. Existing call sites that pass no overrides behave identically.
- **Production call site unchanged.** `lib/Core/App.dart:210` constructs `BiometricBatcher(router: ..., client: ...)` with no overrides — still valid since both new params have defaults. This is the only construction site in the codebase (confirmed by grep).
- **Field usage intact.** `_maxBatchSize` is still read in `_onSample` (`_buffer.length >= _maxBatchSize`) and `_flushInterval` in the lazy timer (`Timer(_flushInterval, _flushNow)`). Both now resolve to instance fields. Flush/dispose logic untouched.
- **Const-correctness.** The default `const Duration(milliseconds: 250)` is a valid compile-time constant for a default parameter value. `final` instance fields assigned in the initializer list compile correctly.
- **No leaked mutability or race introduced.** Fields are `final`; no new async, no new shared state.

## Findings
None. The refactor is minimal, additive, and preserves existing behavior while enabling injection of small interval / batch size in tests.

REVIEW_PASS
