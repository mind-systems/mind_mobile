# Plan Review: Make `ModuleInstructionStream` testable — inject Clock for rate-limit timing

**Plan file:** `100-make-moduleinstructionstream-testable-inject-clock-for-rate-limit-timing.md`
**Risk Level:** 🟢 Low

## Verification Against Codebase

All claims in the plan check out against the actual source:

- **Constructor shape (Task 1).** `ModuleInstructionStream` (lib/Core/Grpc/ModuleInstructionStream.dart:47-51) uses a named-parameter constructor with two `required` params (`connectionManager`, `instructionStreamService`) and an initializer list. Adding `DateTime Function() clock = DateTime.now` as an optional named param plus `_clock = clock` in the initializer list is a clean, non-breaking change. ✅
- **Callsite stability.** The only caller, `lib/Core/App.dart:231`, passes both params by name and does not pass `clock` — confirmed. Defaulting `clock` to `DateTime.now` keeps this callsite valid with zero edits. ✅
- **Pattern reference.** `lib/Biometrics/ActiveRrSource.dart:28-34` does exactly what the plan mirrors: `DateTime Function() clock = DateTime.now` param + `final DateTime Function() _clock;` field + `_clock = clock` in the initializer list. The plan's stylistic guidance matches the real reference. ✅
- **Two `DateTime.now()` call sites (Task 2).** In `emit()` there are exactly two: line 87 (`DateTime.now().difference(_lastSendTime!)`, the rate-limit comparison) and line 95 (`_lastSendTime = DateTime.now()`, the assignment). Both are inside the `_isReady` branch and both should become `_clock()`. ✅
- **No other `DateTime`/timer usage to touch.** The fallback `_readyTimeout` is a `Duration` constant (line 32) and `Timer` usage is unrelated to wall-clock timing. The plan correctly scopes the change to only the two `emit()` calls. `_lastSendTime` resets (lines 61, 113) store `null`, not a clock read, so they are correctly left alone. ✅

## Findings

### Critical Issues
None.

### Minor Notes (non-blocking)

- **Settings say "Testing: no" while the task's purpose is testability.** The plan intentionally only injects the seam without adding tests — that is a legitimate scope decision (enables future tests without writing them now). No action required, but worth confirming this matches intent: the deliverable is the injectable seam, not a test suite.
- **Field ordering nuance.** The plan says to place `_clock` initialization "alongside the other field initializers." In the current constructor the body also runs `connectionManager.connectionState.listen(...)`. Since `_clock` is only read inside `emit()` (never during construction), ordering relative to the listener setup is immaterial — no race. Just initialize it in the initializer list as described.

### Positive Notes
- The plan explicitly calls out the named-vs-positional trap: the referenced "post-refactor API sketch" used positional params, but the real constructor and its sole caller use named params. Keeping named params avoids breaking `App.dart:231`. This is exactly the right call and is documented in the Task 1 note.
- Scope is tight and surgical: one file, two mechanical substitutions, one additive constructor param with a safe default. Backward-compatible by construction.
- Mirrors an existing, proven in-repo pattern (`ActiveRrSource`) rather than inventing a new convention.

PLAN_REVIEW_PASS
