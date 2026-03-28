# Plan: Rename `TelemetryBuffer` → `InstructionBuffer`

## Context

Complete the rename that was partially done in milestone 42. `InstructionBuffer.dart` (class + file) already exists and the test already imports it, but the old `TelemetryBuffer.dart` was never deleted, the test file still uses the old name, and two documentation files still reference the old class name.

## Settings
- Testing: no
- Logging: minimal
- Docs: yes (update existing references)

## Tasks

### Phase 1: Source cleanup

- [x] **Task 1: Delete the old `TelemetryBuffer.dart` file**
  Files: `lib/Core/Grpc/TelemetryBuffer.dart`
  Delete `lib/Core/Grpc/TelemetryBuffer.dart`. It is dead code — no source file imports it. `lib/Core/Grpc/InstructionBuffer.dart` is the replacement and is already in use.

- [x] **Task 2: Rename the test file `telemetry_buffer_test.dart` → `instruction_buffer_test.dart`**
  Files: `test/Core/Grpc/telemetry_buffer_test.dart`
  Rename the file from `telemetry_buffer_test.dart` to `instruction_buffer_test.dart`. The file contents already reference `InstructionBuffer` everywhere — only the filename needs to change.

### Phase 2: Documentation updates

- [x] **Task 3: Update `docs/core/testing.md`**
  Files: `docs/core/testing.md`
  Line 25: change `TelemetryBuffer` → `InstructionBuffer` in the "Pure calculators / data structures" table row.

- [x] **Task 4: Update `docs/socket/live-session-tracking.md`**
  Files: `docs/socket/live-session-tracking.md`
  Line 60: change `TelemetryBuffer` → `InstructionBuffer`. This doc is in Russian — preserve the surrounding language; only change the class name.
