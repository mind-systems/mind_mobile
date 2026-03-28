## Code Review Summary

**Files Reviewed:** 6 (1 deleted, 1 renamed, 4 modified)
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md** — WARN: none. `BreathModuleInstructionStream` lives in `lib/BreathModule/Core/` (domain/infrastructure layer), consistent with the folder structure conventions. The deleted `IBreathTelemetryService` had no ViewModel consumer in the package — removing it resolves an architectural dead-end. `BreathModuleStateChannel` correctly depends on the concrete type directly since it lives in `lib/` (not in the package).
- **RULES.md** — WARN: none. `BreathModuleInstructionStream` is not a Module Service (it does not implement an `IXxxService` from a package), so the statelessness rule does not apply. It manages `StreamSubscription`s for acks and ready events, which is correct for a domain-layer infrastructure class. All dependencies are constructor-injected.
- **ROADMAP.md** — WARN: none. Section 7.6 item "Rename `BreathTelemetryService` → `BreathModuleInstructionStream`" is marked `[x]`. The second item "Remove `IBreathTelemetryService` interface" was also completed by this plan (both tasks executed in a single commit). The roadmap checkbox for the interface removal was updated in a follow-up commit (plan 48).

### Task-by-Task Verification

**Task 1 — Delete IBreathTelemetryService interface and remove barrel export** ✓
- `packages/breath_module/lib/src/BreathSession/IBreathTelemetryService.dart` deleted.
- Export line removed from `packages/breath_module/lib/breath_module.dart`.

**Task 2 — Rename concrete class file and remove interface dependency** ✓
- File renamed `BreathTelemetryService.dart` → `BreathModuleInstructionStream.dart`.
- Class and constructor renamed.
- `import ... show IBreathTelemetryService` removed.
- `implements IBreathTelemetryService` clause removed.
- `@override` on `sendSample` correctly removed (no longer implementing an interface).
- All internal logic (rate limiting, `InstructionBuffer`, `sendSample`, `flushBuffer`, `_emit`, `_canSendNow`, `_onDataAck`, `dispose`) unchanged.

**Task 3 — Update BreathModuleStateChannel** ✓
- Import path updated.
- Field `_telemetryService` → `_instructionStream`, constructor parameter `telemetryService` → `instructionStream`.
- Both call sites updated (lines 100 and 107).

**Task 4 — Update App.dart** ✓
- Import updated (line 40).
- Field `telemetryService` → `breathInstructionStream` (line 76).
- Constructor parameter updated (line 98).
- Local variable renamed in `initialize()` (line 164).
- `shared = App._(...)` assignment updated (line 183).

**Task 5 — Update BreathModule assembly point** ✓
- Named argument changed to `instructionStream: App.shared.breathInstructionStream` (line 43).

### Stale Reference Check

Grep across `lib/`, `packages/`, and `test/` for `BreathTelemetryService` and `IBreathTelemetryService` — zero hits. The rename is complete with no orphaned references.

### Critical Issues

None.

### Suggestions

None.

### Positive Notes

- Clean, mechanical rename with no behavioral changes — exactly what the plan called for.
- `@override` annotation correctly removed alongside the `implements` clause.
- Naming is consistent: `breathInstructionStream` (App.dart field) wraps `instructionStream` (ModuleInstructionStream) — clear hierarchy.
- No collateral damage: `GrpcClient.telemetryService` (`TelemetryServiceClient`) and `ModuleInstructionStream._telemetryService` are gRPC-layer concerns, correctly untouched.

REVIEW_PASS
