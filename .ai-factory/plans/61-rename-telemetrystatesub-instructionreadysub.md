# Plan: Rename `_telemetryStateSub` to `_instructionReadySub`

## Context
Rename a misleadingly named subscription field in `BreathModuleInstructionStream` so the name reflects what it actually listens to (`_instructionStream.readyEvents`).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Rename

- [x] **Task 1: Rename `_telemetryStateSub` → `_instructionReadySub` in BreathModuleInstructionStream**
  Files: `lib/BreathModule/Core/BreathModuleInstructionStream.dart`
  Replace all three occurrences of `_telemetryStateSub` with `_instructionReadySub`:
  - Line 15 — field declaration: `StreamSubscription<void>? _telemetryStateSub;` → `StreamSubscription<void>? _instructionReadySub;`
  - Line 20 — assignment in constructor: `_telemetryStateSub = _instructionStream.readyEvents.listen(...)` → `_instructionReadySub = ...`
  - Line 56 — cancel in `dispose()`: `_telemetryStateSub?.cancel();` → `_instructionReadySub?.cancel();`
  No other files reference this private field.
