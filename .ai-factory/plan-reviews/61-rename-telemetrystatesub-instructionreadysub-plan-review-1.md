## Plan Review: Rename `_telemetryStateSub` → `_instructionReadySub`

**Files in scope:** 1
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md:** WARN — no concerns; private field rename within a single domain-layer class, no boundary or dependency changes.
- **RULES.md:** WARN — no violations; no stateful service, no App.dart change, no DI wiring change.
- **ROADMAP.md:** WARN — plan maps exactly to Phase 10.1 task. Alignment is correct.
- **Skill context:** WARN — `aif-review/SKILL.md` does not exist; skipped.

### Verification

| Plan claim | Actual codebase | Match |
|---|---|---|
| Field at line 15: `StreamSubscription<void>? _telemetryStateSub;` | Line 15: exact match | ✅ |
| Assignment at line 20: `_telemetryStateSub = _instructionStream.readyEvents.listen(...)` | Line 20: exact match | ✅ |
| Cancel at line 56: `_telemetryStateSub?.cancel();` | Line 56: exact match | ✅ |
| "No other files reference this private field" | `grep` confirms only `BreathModuleInstructionStream.dart` contains `_telemetryStateSub` in source code | ✅ |

### Critical Issues

None.

### Suggestions

None.

### Positive Notes

- The plan is precise: correct file path, correct line numbers, all three occurrences identified.
- The new name `_instructionReadySub` accurately reflects the subscription's purpose (`_instructionStream.readyEvents`).
- Correctly scoped — a trivial private rename with zero blast radius.

PLAN_REVIEW_PASS
