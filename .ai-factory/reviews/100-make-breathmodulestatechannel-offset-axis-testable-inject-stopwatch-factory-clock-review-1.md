# Code Review: Make `BreathModuleStateChannel` offset axis testable

**Scope reviewed:** `git diff HEAD` + `git status`
**Code files changed:**
- `lib/BreathModule/Core/BreathModuleStateChannel.dart`
- `test/BreathModule/breath_module_state_channel_test.dart`

(The `.ai-factory/` files — plan, plan-review, json — are process artifacts, not code; not reviewed for correctness.)

**Verification:** `flutter test test/BreathModule/breath_module_state_channel_test.dart` → **All 56 tests pass.**

---

## Summary

This is a clean, behavior-preserving DI-seam refactor. Two optional named constructor parameters (`stopwatchFactory`, `clock`) are introduced with defaults that exactly reproduce the prior behavior (`Stopwatch.new`, `DateTime.now`), and the test fake is extended to capture the full 5-tuple while existing assertions are routed through a `phaseTickCalls` projection getter to stay deterministic. The implementation matches the plan precisely.

## Correctness checks (all verified against source)

- **All `DateTime.now()` call sites in the SUT are now clock-driven.** Grep-equivalent read of the full file confirms the only remaining time sources are `_clock()` at line 90 (`_originWallClock` capture) and line 145 (`_wireTimestamp` fallback). No stray `DateTime.now()` remains. ✅
- **Initializer-list ordering is safe.** `_stopwatch = stopwatchFactory()` and `_clock = clock` are assigned in the initializer list (lines 42–43), before the constructor body runs. The body's stream listeners do not touch `_stopwatch`/`_clock` synchronously, and `_clock`/`_stopwatch` are only dereferenced later inside `_handleLifecycle`/`_wireTimestamp`. No use-before-init. ✅
- **Single Stopwatch instance preserved.** The factory is invoked exactly once at construction; the same instance is reused across `reset()`/`start()` via cascade (`..reset()..start()` / `..stop()..reset()`), identical to the prior inline-field semantics. ✅
- **`Stopwatch.new` / `DateTime.now` tear-offs are legal const-defaultable values** and compile (confirmed by the green test run, which constructs the SUT via the defaulted `_make()` path). ✅
- **No call sites break.** Both new params are optional with defaults; the production wiring (`BreathModule.dart`) and the test `_make()` are unaffected. ✅
- **`sendSample` interface unchanged** — it already accepted the 5-tuple, so the fake's signature still satisfies `BreathModuleInstructionStream`. ✅

## Test-change checks

- **Fake now records the full 5-tuple** (`sendSampleCalls` is `List<(String, String, int, int, int)>`), so future offset/timestamp assertions are possible — the milestone's stated goal. ✅
- **`phaseTickCalls` projection is correct and decouples existing equality assertions from the nondeterministic `offsetMs`/`timestampMs`** produced by the real default `Stopwatch`/clock. Without this, naive 5-tuple equality would flake. ✅
- **Every tuple-equality site was migrated; none missed.** I grepped for any surviving `sendSampleCalls<accessor>, (` equality pattern → zero matches. All remaining `sendSampleCalls` references are `hasLength`/`isEmpty` checks or single-field `.$1` reads (lines 1094, 1220), all of which remain valid on a 5-tuple (`.$1` = sessionId in both shapes). ✅

## Runtime-risk assessment

- No migrations, no schema, no serialization, no async ordering changes. The refactor is purely a constructor seam.
- Wire behavior is byte-identical in production: `_clock()` defaults to `DateTime.now`, so `clientTimestampMs` and `_wireTimestamp` outputs are unchanged for real callers.
- No race conditions introduced — field assignment is synchronous in the initializer list.

## Findings

None.

REVIEW_PASS
