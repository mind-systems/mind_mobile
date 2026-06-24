# Code Review: Make `HeartRateTickService` testable: inject grace-window Duration

**Branch:** phase-55-serialize-bci-lifecycle
**Scope reviewed:** `lib/BreathModule/HeartRateTickService.dart` (only code change; the other staged files are plan/plan-review artifacts)

## Summary

The change adds a named constructor parameter `Duration graceWindow = const Duration(seconds: 10)`, stores it in a new `final Duration _graceWindow` instance field via the initializer list, removes the `static const Duration _coastGraceWindow`, and points `_armGrace()` at the new field. The class doc comment was updated to stop referencing the removed symbol.

## Verification

- **Correctness of the refactor:** `_graceWindow` is a `final` field assigned in the initializer list (`_graceWindow = graceWindow`) before the constructor body runs, so it is available where it is used (`_armGrace`, line 152). The default value `const Duration(seconds: 10)` is identical to the removed constant, so behavior is unchanged for existing callers.
- **Call sites:** The only production instantiation is `lib/BreathModule/BreathModule.dart:33` — `HeartRateTickService(smoothedRrSource: App.shared.smoothedRrSource)..start()`. It does not pass `graceWindow`, so it picks up the default and is unaffected. Adding an optional named parameter is non-breaking.
- **Removed symbol:** `_coastGraceWindow` has no remaining references in `lib/` or `test/`. The test fake `_FakeHeartRateTickService` in `test/BreathModule/switchable_tick_service_test.dart` does not reference the real class internals, so it is unaffected. Other `_coastGraceWindow` matches are only in `.ai-factory/` notes/plans (documentation), which are out of scope for runtime.
- **No leaked usages:** `_armGrace()` is the sole consumer of the grace duration; both arming-at-construction (line 50) and re-arming on genuine beats (line 145) route through it.
- **Doc comment:** Line 19 now reads "within the grace window (default 10 s)" — no dangling `[_coastGraceWindow]` doc reference remains.

## Findings

None. The change is minimal, matches the plan exactly, is non-breaking, and introduces no runtime risk (no type mismatch, no nullability issue, no lifecycle/race change — the timer plumbing is untouched).

REVIEW_PASS
