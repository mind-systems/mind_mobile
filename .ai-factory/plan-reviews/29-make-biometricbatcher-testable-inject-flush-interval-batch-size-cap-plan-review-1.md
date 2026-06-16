# Plan Review: Make `BiometricBatcher` testable (inject flush interval + batch-size cap)

**Plan:** `29-make-biometricbatcher-testable-inject-flush-interval-batch-size-cap.md`
**Risk Level:** 🟢 Low

## Verification Against Codebase

- **`lib/Biometrics/BiometricBatcher.dart`** — Confirmed. Lines 15-16 hold the two `static const` declarations (`_maxBatchSize = 25`, `_flushInterval = Duration(milliseconds: 250)`). The current constructor (lines 25-31) and initializer-list style match what the plan reproduces.
- **Reference sites** — Confirmed. `_maxBatchSize` is used at line 37 (`_buffer.length >= _maxBatchSize`) and `_flushInterval` at line 41 (`_flushTimer ??= Timer(_flushInterval, _flushNow)`). Renaming `static const` to `final` instance fields leaves these references valid with no edit, exactly as the plan states.
- **Production call site** — Confirmed at `lib/Core/App.dart:210`: `BiometricBatcher(router: bioStreamRouter, client: biometricStreamClient)`. With the two new parameters defaulted to the prior constants, this call compiles unchanged. Task 2's "no edit expected" assertion is correct.
- **Doc comment** — Lines 10-11 state the defaults ("25 samples", "250 ms deadline"). The plan correctly instructs leaving these defaults intact, so the comment stays accurate.

## Assessment

The plan is minimal, accurate, and behavior-preserving:
- File paths, line numbers, field names, and the constructor shape all match the actual source.
- Defaults preserve current values, so the only production caller and the documented behavior are unaffected.
- No migrations, security surface, or architectural boundaries are touched — this is a pure constructor-parameterization for testability. It respects the domain-layer purity rule (pure Dart, no Flutter/Riverpod imports introduced).

## Minor Notes (non-blocking)

- The plan's Task 1 description says "the timer creation (`Timer(_flushInterval, _flushNow)`)" — the real line is `_flushTimer ??= Timer(_flushInterval, _flushNow)`. The quoted fragment is accurate as far as the `_flushInterval` reference goes; no action needed.
- Settings declare `Testing: no`. The stated motivation is testability, but the plan only exposes the seams and does not add tests — consistent with the setting. If tests are desired they belong in a follow-up task; not a defect in this plan.

PLAN_REVIEW_PASS
