## Plan Review: Rename `_telemetryStateSub` → `_instructionReadySub`

**Plan file:** `.ai-factory/plans/62-rename-telemetrystatesub-instructionreadysub.md`
**Files in scope:** 1
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md:** WARN — no issues. Private field rename, no boundary or dependency changes.
- **RULES.md:** WARN — no issues. No service/DI/state-management patterns affected.
- **ROADMAP.md:** WARN — plan maps exactly to Phase 10.1. Phase 10.2 (rename `_pendingTelemetry` / `_handleTelemetry` in `BreathModuleStateChannel.dart`) is a separate task and correctly out of scope here.

### Verification

- **Line numbers are accurate:** field declaration (L15), assignment (L20), cancel (L56) — all confirmed against the current file.
- **Occurrence count is complete:** `grep` across the entire repo confirms exactly 3 code occurrences, all in `lib/BreathModule/Core/BreathModuleInstructionStream.dart`. No other file references this private field.
- **New name is appropriate:** the subscription listens to `_instructionStream.readyEvents`, so `_instructionReadySub` accurately describes what it subscribes to.

### Critical Issues

None.

### Suggestions

None.

### Positive Notes

- Scope is correctly limited to the single private field; no over-reaching.
- The plan explicitly lists every occurrence with line numbers, making implementation trivial and verifiable.
- Aligns with the roadmap's Phase 10 cleanup goal of removing residual "telemetry" naming.

PLAN_REVIEW_PASS
