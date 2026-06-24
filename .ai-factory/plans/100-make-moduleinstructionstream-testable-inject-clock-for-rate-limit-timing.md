# Plan: Make `ModuleInstructionStream` testable: inject Clock for rate-limit timing

## Context
Make rate-limiting in `ModuleInstructionStream.emit()` deterministically testable by injecting a `clock` function instead of calling `DateTime.now()` directly, mirroring the pattern already used in `ActiveRrSource`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Inject the clock

- [x] **Task 1: Add `clock` constructor parameter and a backing field**
  Files: `lib/Core/Grpc/ModuleInstructionStream.dart`
  Add an optional named parameter `DateTime Function() clock = DateTime.now` to the existing named-parameter constructor (keep the two `required` params `connectionManager` and `instructionStreamService` unchanged so the `App.dart` callsite stays valid). Store it in a new `final DateTime Function() _clock;` field, initialized in the constructor initializer list (`_clock = clock`), placed alongside the other field initializers. Match the style used in `lib/Biometrics/ActiveRrSource.dart` (`final DateTime Function() _clock;` + `DateTime Function() clock = DateTime.now`).
  Note: the test plan's "post-refactor API" sketches positional params, but the current constructor and its only caller (`lib/Core/App.dart:231`) use named params — keep named to avoid breaking the callsite.

- [x] **Task 2: Replace the two `DateTime.now()` calls in `emit()` with `_clock()`** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleInstructionStream.dart`
  In `emit()`, replace `DateTime.now().difference(_lastSendTime!)` (the rate-limit comparison) and `_lastSendTime = DateTime.now()` (the assignment) with `_clock()`. Do not change any other `DateTime`/timer usage — the fallback timer Duration is already a constant and stays as-is.
