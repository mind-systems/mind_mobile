# Code Review: Rename `_telemetryStateSub` → `_instructionReadySub`

**Plan:** `.ai-factory/plans/61-rename-telemetrystatesub-instructionreadysub.md`
**Files changed:** 1 (`lib/BreathModule/Core/BreathModuleInstructionStream.dart`)
**Risk Level:** Low

## Changes Verified

| Location | Before | After | Correct |
|---|---|---|---|
| Line 15 — field declaration | `_telemetryStateSub` | `_instructionReadySub` | Yes |
| Line 20 — constructor assignment | `_telemetryStateSub = _instructionStream.readyEvents.listen(...)` | `_instructionReadySub = ...` | Yes |
| Line 56 — `dispose()` cancel | `_telemetryStateSub?.cancel()` | `_instructionReadySub?.cancel()` | Yes |

## Completeness

- Grep confirms zero remaining occurrences of `_telemetryStateSub` in any `.dart` file. The old name only survives in documentation/plan files (roadmap, plan reviews), which is expected.
- The new name `_instructionReadySub` correctly describes the subscription target: `_instructionStream.readyEvents`.
- Field is private (`_` prefix) — no external consumers possible.

## Runtime Impact

None. This is a pure rename of a private field within a single class. No behavior, types, or API surface changed.

## Critical Issues

None.

## Suggestions

None.

REVIEW_PASS
