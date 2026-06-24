# Code Review: Make `ModuleInstructionStream` testable — inject Clock for rate-limit timing

**Reviewed file:** `lib/Core/Grpc/ModuleInstructionStream.dart`
**Scope:** Constructor `clock` injection + two `DateTime.now()` → `_clock()` substitutions in `emit()`.

## Summary

The change is a clean, surgical, backward-compatible refactor that exactly matches the plan and mirrors the existing `ActiveRrSource` pattern. No bugs, security issues, or correctness problems found.

## Verification

- **Field & constructor (Task 1).** `final DateTime Function() _clock;` is added and initialized via `_clock = clock` in the initializer list. The new param `DateTime Function() clock = DateTime.now` is an optional named param appended after the two `required` params. `DateTime.now` is a static-method tearoff and a valid compile-time-constant default (identical to `ActiveRrSource.dart:30`), so this compiles. ✅
- **Callsite stability.** The sole caller, `lib/Core/App.dart:231`, passes `connectionManager` and `instructionStreamService` by name and does not pass `clock` — it transparently uses the `DateTime.now` default. Zero edits required, no breakage. ✅
- **Substitutions (Task 2).** Both wall-clock reads in `emit()` are replaced: the rate-limit comparison (`_clock().difference(_lastSendTime!)`, line 93) and the assignment (`_lastSendTime = _clock()`, line 101). Both live inside the `_isReady` branch, which is the only place rate-limit timing is evaluated. ✅
- **No stray `DateTime.now()` left.** Confirmed there are no other `DateTime.now()` calls in the file. The fallback `_readyTimeout` is a `Duration` constant and `Timer` usage is unrelated to wall-clock comparison — correctly left untouched. ✅
- **`_lastSendTime` resets** (lines 67, 119) store `null`, not a clock read, so they are correctly unchanged. ✅

## Runtime / correctness considerations

- **No race condition.** `_clock` is read only inside `emit()`, never during construction, so its position in the initializer list relative to the connection-state listener is immaterial.
- **Type safety.** Field, param, and default all share the `DateTime Function()` signature; `_clock().difference(...)` returns `Duration`, `.inMilliseconds` is `int`, compared against `int minIntervalMs` — types align.
- **Behavioral equivalence.** With the default `DateTime.now`, runtime behavior is byte-for-byte identical to before. The injection only opens a deterministic seam for tests.
- **Pre-existing edge case (not introduced here).** Two `emit()` calls within the same clock tick both pass the rate-limit gate (the comment at line 94 already documents the cap as best-effort). The injected clock now makes this *testable* rather than worsening it — out of scope and intentional.

## Findings

None.

REVIEW_PASS
