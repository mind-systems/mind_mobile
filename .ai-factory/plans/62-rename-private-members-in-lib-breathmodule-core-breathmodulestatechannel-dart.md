# Plan: Rename private members in BreathModuleStateChannel.dart

## Context
Completes the telemetry → instruction rename in the mobile codebase by updating two private members in `BreathModuleStateChannel` that still use the old "telemetry" naming.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Rename

- [x] **Task 1: Rename `_pendingTelemetry` → `_pendingInstruction`**
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  Replace all 5 occurrences of `_pendingTelemetry` with `_pendingInstruction` (field declaration on line 21, assignment on line 97, read on line 104, null-set on line 106, reset on line 117). Use a single find-and-replace — the name is unique to this file.

- [x] **Task 2: Rename `_handleTelemetry` → `_handleInstruction`**
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  Replace both occurrences of `_handleTelemetry` with `_handleInstruction` (call site in `_onState` on line 47, method definition on line 86). Use a single find-and-replace — the name is unique to this file.
