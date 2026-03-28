# Plan: Remove IBreathTelemetryService interface

## Context

Mark the roadmap item as complete — all code changes were already implemented in plan 47 (rename BreathTelemetryService to BreathModuleInstructionStream). The interface file is deleted, the barrel export is removed, `BreathModuleInstructionStream` is the concrete type used at every wiring point, and `BreathModule.dart` already passes `App.shared.breathInstructionStream` to `BreathModuleStateChannel`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Update roadmap

- [x] **Task 1: Check off the roadmap item in ROADMAP.md**
  Files: `.ai-factory/ROADMAP.md`
  In section 7.6, change `- [ ] **Remove \`IBreathTelemetryService\` interface**` to `- [x] **Remove \`IBreathTelemetryService\` interface**`. No other changes — the code is already correct.
