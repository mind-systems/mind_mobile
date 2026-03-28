# Plan: Rename BreathTelemetryService to BreathModuleInstructionStream

## Context

Pure rename of the breath telemetry class and removal of its dead interface, aligning naming with the underlying `ModuleInstructionStream` infrastructure. The class already injects `ModuleInstructionStream` and emits `InstructionSample(phase, durationMs)` on breath phase change — no behavioral changes, rate limiting and `InstructionBuffer` stay as-is. The `IBreathTelemetryService` interface is deleted because no ViewModel in `packages/breath_module/` consumes it — `BreathModuleStateChannel` already depends on the concrete type directly.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Delete interface and rename implementation

- [x] **Task 1: Delete IBreathTelemetryService interface and remove barrel export**
  Files: `packages/breath_module/lib/src/BreathSession/IBreathTelemetryService.dart`, `packages/breath_module/lib/breath_module.dart`
  Delete `IBreathTelemetryService.dart` entirely — no ViewModel in the package consumes this interface, and `BreathModuleStateChannel` uses the concrete type. In `breath_module.dart`, remove the export line `export 'src/BreathSession/IBreathTelemetryService.dart';`.

- [x] **Task 2: Rename concrete class file and remove interface dependency** (depends on Task 1)
  Files: `lib/BreathModule/Core/BreathTelemetryService.dart`
  Rename `BreathTelemetryService.dart` to `BreathModuleInstructionStream.dart`. Inside the file: rename `class BreathTelemetryService` to `class BreathModuleInstructionStream`, remove the `import 'package:breath_module/breath_module.dart' show IBreathTelemetryService;` line entirely, remove the `implements IBreathTelemetryService` clause from the class declaration, and rename the constructor `BreathTelemetryService(...)` to `BreathModuleInstructionStream(...)`. All internal logic (rate limiting, buffer, `sendSample`, `flushBuffer`, `_emit`, `_onDataAck`) stays unchanged.

### Phase 2: Update all consumers

- [x] **Task 3: Update BreathModuleStateChannel** (depends on Task 2)
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  Update the import from `BreathTelemetryService.dart` to `BreathModuleInstructionStream.dart`. Rename the field type `BreathTelemetryService _telemetryService` to `BreathModuleInstructionStream _instructionStream`. Update the constructor parameter from `required BreathTelemetryService telemetryService` to `required BreathModuleInstructionStream instructionStream` and the initializer from `_telemetryService = telemetryService` to `_instructionStream = instructionStream`. Update both call sites: `_telemetryService.sendSample(...)` to `_instructionStream.sendSample(...)` (lines 100 and 107).

- [x] **Task 4: Update App.dart** (depends on Task 2)
  Files: `lib/Core/App.dart`
  Update the import from `BreathTelemetryService.dart` to `BreathModuleInstructionStream.dart`. Rename the field from `final BreathTelemetryService telemetryService` to `final BreathModuleInstructionStream breathInstructionStream`. Update the named constructor parameter from `required this.telemetryService` to `required this.breathInstructionStream`. In `initialize()`, rename the local variable from `telemetryService` to `breathInstructionStream` and update the constructor call `BreathTelemetryService(...)` to `BreathModuleInstructionStream(...)`. Update the `shared = App._(...)` assignment from `telemetryService: telemetryService` to `breathInstructionStream: breathInstructionStream`.

- [x] **Task 5: Update BreathModule assembly point** (depends on Tasks 3, 4)
  Files: `lib/BreathModule/BreathModule.dart`
  In `buildSession()`, update the `BreathModuleStateChannel` constructor call: change the named argument from `telemetryService: App.shared.telemetryService` to `instructionStream: App.shared.breathInstructionStream`.

## Commit Plan
- **Commit 1** (after tasks 1-5): "Rename BreathTelemetryService to BreathModuleInstructionStream and delete dead IBreathTelemetryService interface"
