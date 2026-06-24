# Plan Review: Make `BiometricStreamClient` testable — inject Clock + cooldown/timeout Durations

**Plan file:** `100-make-biometricstreamclient-testable-inject-clock-cooldown-timeout-durations.md`
**Risk Level:** 🟢 Low

## Verification Against Codebase

Every claim in the plan was checked against the actual source:

| Plan claim | Verified |
|---|---|
| Constructor uses named params `{grpcStub, moduleStateEvents, connectionState}` | ✅ `BiometricStreamClient.dart:54–58` |
| Two `DateTime.now()` calls in `_ensureSinkOpen` | ✅ Cooldown compare at line 124, assignment at line 127 |
| Hardcoded `Timer(const Duration(seconds: 5), …)` readiness fallback | ✅ Line 166 |
| `_readyTimer` doc comment says "Fires after 5 s …" | ✅ Lines 50–51 |
| Initializer list is `: _grpcStub = grpcStub {` (new fields go here) | ✅ Line 58 |
| App.dart call site uses only the three required named args | ✅ `lib/Core/App.dart:227` — won't break since new params are optional |

## Architecture & Correctness Notes

- **Correctly overrides the source note.** Note `176-test-plan-biometric-stream-client.md` (lines 376–382) drafts a *positional* constructor signature. Task 1 explicitly rejects that and preserves the named-parameter shape — this is the right call: the positional draft would break the `App.dart:227` call site. Good catch by the plan author to flag this divergence.
- **Defaults preserve behavior.** `clock = DateTime.now` and `readyTimeout = const Duration(seconds: 5)` keep all existing instantiations behaviorally identical, satisfying the Notes invariant. The single production call site omits both, so runtime behavior is unchanged.
- **Cooldown literal left in place is intentional and correct.** Task 2 keeps `const Duration(seconds: 2)` and only swaps the time *source*. Since the injected `_clock()` lets a test advance time deterministically against a fixed window, the 2 s literal does not need to be injectable for the stated testing goal. This is a reasonable scope boundary, not a gap.
- **No migrations, no security surface, no DI wiring changes.** Pure constructor-injection refactor inside a single file; `App.shared` wiring is untouched.

## Minor Observations (non-blocking)

- **`_clock` field naming vs. parameter.** Task 1 names the parameter `clock` and the field `_clock`, requiring `: _clock = clock` in the initializer list. The plan describes initializing "in the initializer list alongside `_grpcStub`" — straightforward, but the implementer should note all three (`_grpcStub`, `_clock`, `_readyTimeout`) are comma-separated before the constructor body `{`. Trivial Dart, just flagging for clarity.
- **Scope note.** Plan Settings say "Testing: no" — this plan only makes the class testable; it does not add the test suite described in note 176. That is consistent with the stated objective (enable deterministic testing), but the actual tests remain a follow-up. Worth confirming that is the intended scope split.

## Context Gates

- **Architecture:** No `.ai-factory/ARCHITECTURE.md` boundary concerns — change is internal to `lib/Biometrics/`, domain layer stays pure Dart (`DateTime Function()` injection introduces no Flutter/Riverpod imports). WARN: none.
- **Rules:** Logging facade unaffected (no new log calls). No raw `print`/`DateTime` rule violations introduced. WARN: none.
- **Roadmap:** Testability refactor; no milestone linkage asserted. Non-blocking.

## Conclusion

The plan is accurate, scoped tightly, and correctly accounts for the one real hazard (constructor signature shape vs. the source note's positional draft). File paths, line targets, and API usage all match the current source. No missing steps, no wrong assumptions, no architectural mistakes.

PLAN_REVIEW_PASS
