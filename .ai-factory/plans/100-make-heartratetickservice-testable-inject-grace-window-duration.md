# Plan: Make `HeartRateTickService` testable: inject grace-window Duration

## Context
Expose the hardcoded 10 s coast-grace window as an injectable constructor parameter so unit tests can drive grace-expiry → `_effectiveActive` flip → `SwitchableTickService` auto-fallback in milliseconds instead of waiting 10 real seconds.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Make grace window injectable

- [x] **Task 1: Add `graceWindow` constructor parameter and replace the static constant**
  Files: `lib/BreathModule/HeartRateTickService.dart`
  In the `HeartRateTickService({...})` constructor (lines 28–31), add a named parameter `Duration graceWindow = const Duration(seconds: 10)` alongside the existing `smoothedRrSource` and `timerFactory`. Assign it to a new `final Duration _graceWindow;` instance field via the constructor initializer list (mirror how `_timerFactory` is initialized). Remove the `static const Duration _coastGraceWindow = Duration(seconds: 10);` declaration (line 54) and replace its single usage in `_armGrace()` (`_graceTimer = _timerFactory(_coastGraceWindow, _onGraceExpired);`, line 151) with `_graceWindow`. Default behavior is unchanged for all existing call sites since the default equals the former constant.

- [x] **Task 2: Update the class-level doc comment reference**
  Files: `lib/BreathModule/HeartRateTickService.dart`
  Update the doc comment on line 19 that reads `if no genuine beat arrives within [_coastGraceWindow] (10 s)` to reference the new injectable field, e.g. `within the grace window (default 10 s)` so the documentation no longer points at the removed `_coastGraceWindow` symbol.
