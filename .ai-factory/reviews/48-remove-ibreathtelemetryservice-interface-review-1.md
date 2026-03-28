# Review: 48 — Remove IBreathTelemetryService interface

## Scope

Two staged files:
1. `.ai-factory/ROADMAP.md` — checkbox flip `[ ]` → `[x]` on the "Remove `IBreathTelemetryService` interface" item in §7.6.
2. `.ai-factory/plans/48-remove-ibreathtelemetryservice-interface.md` — new plan file documenting that the work was already completed in plan 47.

No application code changes.

## Verification of underlying claim

The plan asserts all code changes were completed in plan 47. Confirmed by grep over `lib/` and `packages/`:

- `IBreathTelemetryService` — zero hits in `lib/`, zero hits in `packages/`
- `IBreathTelemetryService.dart` — file does not exist anywhere in the repo
- `breath_module.dart` barrel — no export line referencing `IBreathTelemetryService`
- `BreathModuleInstructionStream` is the concrete type at every wiring point:
  - `App.dart:76` — `final BreathModuleInstructionStream breathInstructionStream`
  - `App.dart:164` — `BreathModuleInstructionStream(instructionStream: instructionStream)`
  - `BreathModuleStateChannel.dart:12` — `final BreathModuleInstructionStream _instructionStream`
  - `BreathModule.dart:43` — `instructionStream: App.shared.breathInstructionStream`

All claims in the plan are accurate.

## Issues

None.

REVIEW_PASS
