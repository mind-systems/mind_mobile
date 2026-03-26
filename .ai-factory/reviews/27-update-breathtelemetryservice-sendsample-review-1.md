## Code Review Summary

**Files Reviewed:** 2
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md** — WARN: No violations. `BreathTelemetryService` lives in `lib/BreathModule/Core/` (domain/infrastructure layer). `LiveSessionGrpcService` lives in `lib/Core/Grpc/` (infrastructure). Neither leaks domain types into the module boundary. No Flutter or Riverpod imports present.
- **RULES.md** — WARN: No violations. `BreathTelemetryService` is a domain-layer telemetry service, not a Module Service (it does not implement an `IXxxService` declared in a package). The statelessness rule does not apply. All dependencies are constructor-injected.
- **ROADMAP.md** — WARN: Milestone "Update `BreathTelemetryService.sendSample()`" under Phase 3.5 is marked `[x]`. Changes align with the milestone scope.

### Critical Issues

None.

### Suggestions

None.

### Positive Notes

- **Minimal, focused change**: Only 4 lines changed across 2 files — adds the discriminator fields at the source and reads them dynamically at the transport layer. No unnecessary refactoring.
- **Both send paths covered**: `_emit()` (direct send) and `flushBuffer()` (buffered send) both pass through the same payload map built by `sendSample()`, so the discriminator fields are present in both paths without code duplication.
- **Null-safe fallback is consistent**: `data['module_id'] as String? ?? ''` matches the existing pattern used for `sessionId` on the same `TelemetryData` constructor. The empty-string fallback is correct — protobuf string fields default to `""` anyway.
- **Interface untouched**: `IBreathTelemetryService.sendSample(String, String, int)` is unchanged — the discriminator fields are transport-level implementation details of the concrete `BreathTelemetryService`, which is the correct boundary.
- **No orphaned callers**: `emitTelemetry` is only called from `BreathTelemetryService` (two call sites), both using payloads from `sendSample()`. No other caller will silently produce empty `moduleId`/`instructionType`.

REVIEW_PASS
