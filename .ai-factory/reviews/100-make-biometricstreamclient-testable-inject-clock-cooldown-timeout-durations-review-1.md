# Code Review: Make `BiometricStreamClient` testable — inject Clock + cooldown/timeout Durations

**Reviewed:** `lib/Biometrics/BiometricStreamClient.dart` (only code file changed)
**Scope:** `git diff HEAD` — staged plan/json artifacts plus the one source edit.

## Summary

The change adds two optional named constructor parameters — `clock` (default `DateTime.now`) and `readyTimeout` (default `const Duration(seconds: 5)`) — backed by `final` fields `_clock` and `_readyTimeout`, and routes the two `DateTime.now()` cooldown calls and the readiness fallback timer through them. The edit matches the plan precisely.

## Correctness

- **Constructor shape preserved.** The existing required named params (`grpcStub`, `moduleStateEvents`, `connectionState`) are untouched; the two new params are optional with defaults. The only production call site, `lib/Core/App.dart:227`, passes only the three required named args and continues to compile unchanged. No other production instantiations exist (the `biometric_batcher_test.dart` matches are a local `_FakeBiometricStreamClient`, not this class).
- **Initializer list correct.** `_clock = clock` and `_readyTimeout = readyTimeout` are added alongside `_grpcStub = grpcStub`; field declarations are `final` and non-nullable, correctly initialized before the constructor body runs.
- **Cooldown semantics unchanged.** Both `DateTime.now()` sites in `_ensureSinkOpen` now call `_clock()`. The `< const Duration(seconds: 2)` window literal is left in place as intended — only the time source is injected. With the default `DateTime.now`, behavior is byte-for-byte identical to before. Reading `_clock()` twice (once for the diff, once for the assignment) is the same pattern as the original two `DateTime.now()` calls, so no new ordering concern.
- **Timer Duration injected cleanly.** `Timer(_readyTimeout, ...)` replaces `Timer(const Duration(seconds: 5), ...)`; the timer body (`!_isReady` guard, drain, clear) is unchanged. Default value reproduces the original 5 s behavior.
- **Doc comments updated** to reference `[_readyTimeout]` instead of a hardcoded "5 s", keeping the docs honest about the configurability.

## Runtime risk assessment

- No nullability, type-mismatch, or async-ordering changes. `_clock` is non-nullable with a default, so it can never be null at call time.
- A test injecting a non-monotonic or frozen fake clock could make the cooldown comparison behave unexpectedly, but that is the intended test surface, not a defect in this code.
- No migrations, schema, or proto surface touched.

## Findings

None.

REVIEW_PASS
