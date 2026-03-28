## Code Review Summary

**Files in Plan:** 6 (interface deleted, concrete class renamed, state channel, App.dart, barrel export, assembly point)
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md** — No violations. The dead `IBreathTelemetryService` interface (which had no ViewModel consumer in the package) is removed, resolving the prior architectural violation. `BreathModuleStateChannel` correctly depends on the concrete `BreathModuleInstructionStream` type directly.
- **RULES.md** — No violations. `BreathModuleInstructionStream` is not a module-boundary Service — it's a domain-layer instruction emitter. Statelessness rule does not apply. All dependencies are constructor-injected.
- **ROADMAP.md** — No violations. §7.6 defines two items: (1) rename `BreathTelemetryService` → `BreathModuleInstructionStream`, and (2) remove `IBreathTelemetryService` interface. Both are implemented correctly.

### Task-by-Task Verification

**Task 1 — Delete interface and remove barrel export** ✓
- `IBreathTelemetryService.dart` deleted
- Export line removed from `breath_module.dart` (line 14 in old, gone in new)

**Task 2 — Rename concrete class and remove interface dependency** ✓
- File renamed `BreathTelemetryService.dart` → `BreathModuleInstructionStream.dart`
- Class renamed, constructor renamed
- `import ... show IBreathTelemetryService` removed
- `implements IBreathTelemetryService` removed from class declaration
- `@override` on `sendSample` correctly removed (no longer implementing interface)
- All internal logic (`sendSample`, `flushBuffer`, `_emit`, `_canSendNow`, `_onDataAck`, rate limiting, `InstructionBuffer`) unchanged

**Task 3 — Update BreathModuleStateChannel** ✓
- Import updated
- Field `_telemetryService` → `_instructionStream`
- Constructor parameter `telemetryService` → `instructionStream`
- Both call sites updated: line 100 (`_instructionStream.sendSample(...)`) and line 107 (`_instructionStream.sendSample(...)`)

**Task 4 — Update App.dart** ✓
- Import updated (line 40)
- Field `telemetryService` → `breathInstructionStream` (line 76)
- Constructor parameter updated (line 98)
- Local variable renamed (line 164): `BreathModuleInstructionStream(instructionStream: instructionStream)`
- Assignment updated (line 183)

**Task 5 — Update BreathModule assembly point** ✓
- Named argument changed to `instructionStream: App.shared.breathInstructionStream` (line 43)

### Stale Reference Check

Full grep over `lib/`, `packages/`, and `test/` for `BreathTelemetryService`, `IBreathTelemetryService`, and the old `telemetryService` field name — zero hits. Remaining `telemetryService` references in `lib/Core/Grpc/` are the gRPC-layer `TelemetryServiceClient` — separate namespace, correctly untouched.

### Critical Issues

None.

### Suggestions

None.

### Positive Notes

- **Clean interface removal.** The `@override` annotation on `sendSample` was correctly removed alongside the `implements` clause — no orphaned annotations.
- **Complete consumer coverage.** All five consumers identified and updated; zero stale references confirmed by grep.
- **No collateral damage.** `GrpcClient.telemetryService` (`TelemetryServiceClient`) and `ModuleInstructionStream._telemetryService` are gRPC-layer concerns — correctly untouched.
- **Naming consistency.** `breathInstructionStream` on `App.dart` pairs naturally with the existing `instructionStream` (`ModuleInstructionStream`) field — clear hierarchy.

REVIEW_PASS
