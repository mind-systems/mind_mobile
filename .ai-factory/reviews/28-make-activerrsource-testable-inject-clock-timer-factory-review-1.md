# Code Review: Make `ActiveRrSource` testable: inject clock + Timer factory

**Reviewed:** `lib/Biometrics/ActiveRrSource.dart` (the only code file changed)
**Date:** 2026-06-17

## Scope
The diff adds two optional named constructor parameters — `clock` (default `DateTime.now`) and `timerFactory` (default `Timer.new`) — stored in `final` fields, and routes the three previously-hardcoded time accesses through them:
- `_onInterval`: `DateTime.now()` → `_clock()`
- `_onSilence`: `DateTime.now()` → `_clock()`
- `_restartWatchdog`: `Timer(effective, _onSilence)` → `_timerFactory(effective, _onSilence)`

## Verification

**Behavior preservation.** With default parameters the implementation is byte-for-byte equivalent in behavior to the previous code: `_clock()` resolves to `DateTime.now()` and `_timerFactory(...)` resolves to `Timer(...)`. No control flow, silence-window computation, failover walk, priority/preemption, `_ensureHasActive`, or `dispose()` logic was altered. Confirmed against the full file.

**Tearoff type correctness.**
- `DateTime.now` is a static-method tearoff of type `DateTime Function()` — matches the `clock` parameter type.
- `Timer.new` is the unnamed-constructor tearoff of `Timer(Duration duration, void Function() callback)`, type `Timer Function(Duration, void Function())` — matches the `timerFactory` parameter type.
- Constructor/static tearoffs require Dart ≥ 2.15; project targets Dart 3.11+, so this compiles.

**Production call site.** `lib/Core/App.dart:208` (`ActiveRrSource([bciProvider])`) passes no overrides; both new parameters are optional with defaults, so it compiles and behaves unchanged. No other call sites exist (grep confirmed).

**No leftover direct references.** No remaining `DateTime.now()` or raw `Timer(` constructions in the file — all routed through the injected seams.

**Plan adherence.** Both tasks implemented exactly as specified. Aligns with project Rule 3 (dependencies injected via constructor).

## Findings
None. The refactor is correct, minimal, and behavior-preserving.

REVIEW_PASS
