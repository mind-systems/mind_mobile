# Plan: Make `BiometricStreamClient` testable — inject Clock + cooldown/timeout Durations

## Context
Replace the two wall-clock `DateTime.now()` calls and the hardcoded 5 s readiness-fallback `Duration` in `BiometricStreamClient` with injectable constructor parameters, so tests can drive the 2 s reopen-cooldown and the readiness-timeout deterministically.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Inject clock and readyTimeout

- [x] **Task 1: Add `clock` and `readyTimeout` constructor parameters and backing fields**
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  Keep the existing **named-parameter** constructor style (do not switch to positional params as drafted in the note — the existing `BiometricStreamClient({required ... grpcStub, required ... moduleStateEvents, required ... connectionState})` shape must be preserved so the `App.dart` call site keeps compiling unchanged).
  - Add two optional named parameters with defaults:
    - `DateTime Function() clock = DateTime.now`
    - `Duration readyTimeout = const Duration(seconds: 5)`
  - Add two `final` fields and initialize them in the initializer list alongside `_grpcStub`:
    - `final DateTime Function() _clock;`
    - `final Duration _readyTimeout;`
  - Place the new params after the existing required ones inside the same `{ ... }` block. Confirm both new params are optional (defaulted) so all current instantiations stay valid.

- [x] **Task 2: Use `_clock()` for the 2 s reopen-cooldown check in `_ensureSinkOpen`** (depends on Task 1)
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  In `_ensureSinkOpen` replace both `DateTime.now()` calls (the cooldown comparison `DateTime.now().difference(_lastOpenAttempt!)` and the assignment `_lastOpenAttempt = DateTime.now()`) with `_clock()`. Leave the `const Duration(seconds: 2)` cooldown window literal as-is — only the time source is injected.

- [x] **Task 3: Use `_readyTimeout` for the readiness fallback timer in `_ensureSinkOpen`** (depends on Task 1)
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  Replace the hardcoded `Timer(const Duration(seconds: 5), () { ... })` construction with `Timer(_readyTimeout, () { ... })`. Keep the timer body unchanged. Update the doc comment on `_readyTimer` (currently "Fires after 5 s ...") to refer to the configurable timeout instead of a fixed 5 s.

## Notes
- Behavior must be identical when the new parameters are omitted (defaults `DateTime.now` and `Duration(seconds: 5)`).
- Single commit — fewer than 5 tasks, no commit checkpoints needed. Suggested message: "Inject clock and readiness timeout into BiometricStreamClient".
