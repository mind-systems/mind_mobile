# Plan: Update BreathTelemetryService.sendSample()

## Context

Currently `BreathTelemetryService.sendSample()` builds a payload with only `{ sessionId, timestamp, data: { phase, durationMs } }` and the type discriminator fields (`module_id`, `instruction_type`) are hardcoded deep inside `LiveSessionGrpcService.emitTelemetry()`. This milestone moves the discriminator to the caller so the payload is self-describing at every layer of the stack.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Add discriminator fields to the telemetry payload

- [x] **Task 1: Add `module_id` and `instruction_type` to the payload map in `BreathTelemetryService.sendSample()`**
  Files: `lib/BreathModule/Core/BreathTelemetryService.dart`
  In `sendSample()`, add two keys to the top-level payload map alongside `sessionId` and `timestamp`:
  ```dart
  'module_id': 'breath',
  'instruction_type': 'breath_phase',
  ```
  The full payload becomes `{ sessionId, timestamp, module_id, instruction_type, data: { phase, durationMs } }`. No changes to the method signature or the `IBreathTelemetryService` interface — these are implementation-level transport fields.

- [x] **Task 2: Read `module_id` and `instruction_type` from the payload map in `LiveSessionGrpcService.emitTelemetry()`** (depends on Task 1)
  Files: `lib/Core/Grpc/LiveSessionGrpcService.dart`
  In `emitTelemetry()`, replace the hardcoded `moduleId: 'breath'` and `instructionType: 'breath_phase'` with values read from the incoming map:
  ```dart
  moduleId: data['module_id'] as String? ?? '',
  instructionType: data['instruction_type'] as String? ?? '',
  ```
  This makes the gRPC transport layer generic — it forwards whatever discriminator the caller provides instead of assuming breath-specific values. The fallback to empty string keeps the proto valid if a caller omits the fields.
