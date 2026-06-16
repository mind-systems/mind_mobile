# Plan: Make `ActiveRrSource` testable: inject clock + Timer factory

## Context
Replace the direct `DateTime.now()` calls and inline `Timer(...)` construction in `ActiveRrSource` with injectable `clock` and `timerFactory` constructor parameters (both with production defaults) so time-based behavior can be driven deterministically in tests without real delays.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Inject time dependencies

- [x] **Task 1: Add `clock` and `timerFactory` constructor parameters**
  Files: `lib/Biometrics/ActiveRrSource.dart`
  Add two named optional parameters to the constructor with production defaults so existing call sites keep working unchanged:
  ```dart
  ActiveRrSource(
    List<IRrIntervalSource> sources, {
    DateTime Function() clock = DateTime.now,
    Timer Function(Duration, void Function()) timerFactory = Timer.new,
  })  : _sources = List.unmodifiable(sources),
        _clock = clock,
        _timerFactory = timerFactory {
    ...
  }
  ```
  Store them in two `final` fields: `final DateTime Function() _clock;` and `final Timer Function(Duration, void Function()) _timerFactory;`. Keep the existing subscription-setup loop in the constructor body unchanged. The production call site `lib/Core/App.dart:208` (`ActiveRrSource([bciProvider])`) passes no overrides and must compile without modification.

- [x] **Task 2: Route all time access through the injected dependencies** (depends on Task 1)
  Files: `lib/Biometrics/ActiveRrSource.dart`
  Replace every direct time/timer use with the injected functions:
  - In `_onInterval`: `_lastSeenAt[index] = DateTime.now();` → `_lastSeenAt[index] = _clock();`
  - In `_onSilence`: `final now = DateTime.now();` → `final now = _clock();`
  - In `_restartWatchdog`: `_watchdog = Timer(effective, _onSilence);` → `_watchdog = _timerFactory(effective, _onSilence);`
  Do not change any other logic — silence-window computation, failover walk, priority/preemption, `_ensureHasActive`, and `dispose()` stay exactly as they are. Verify no remaining `DateTime.now()` or `Timer(` references exist in the file after the edits.

## Notes
- This is a behavior-preserving refactor: with the default parameters the runtime behavior is identical to the current implementation. The test file described in `.ai-factory/notes/90-test-plan-active-rr-source.md` is out of scope for this milestone (Testing: no) — this plan only delivers the injectable seams the test plan depends on.
- Aligns with project Rule 3 (all dependencies injected via constructor).
