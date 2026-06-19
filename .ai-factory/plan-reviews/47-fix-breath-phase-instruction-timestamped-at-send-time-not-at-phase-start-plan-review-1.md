# Plan Review: Fix — breath phase instruction timestamped at send time, not at phase start

**Plan:** `47-fix-breath-phase-instruction-timestamped-at-send-time-not-at-phase-start.md`
**Risk Level:** 🟢 Low

## Summary

The plan is correct, minimal, and tightly scoped. It faithfully implements the
fix described in spec note `104-phase-instruction-event-time-timestamp.md` and
ROADMAP line 139. All file paths, line references, and API signatures in the plan
match the current codebase. No missing steps, wrong assumptions, or architectural
mistakes found.

## Verification Against Codebase

**Task 1 — `sendSample` signature** ✅
- `BreathModuleInstructionStream.sendSample` confirmed at line 23 with current
  signature `(String sessionId, String phase, int durationMs)`.
- The internal `DateTime.now().millisecondsSinceEpoch` stamp is at line 26 (plan
  says "current line 26" — correct; note 104 said line 27, the plan corrected it).
- `_canSendNow()`/`_emit()`/`_lastSendTime` use `DateTime.now()` for rate-limiting
  independently — the plan correctly instructs leaving these untouched. The payload
  `'timestamp'` is read back as `int` in both `_emit` (line 69) and `flushBuffer`
  (line 48), so passing `timestampMs` (an `int`) is type-consistent end to end.

**Task 2 — capture transition time + thread through pending/flush** ✅
- `_handleInstruction` (lines 88–103) and the `if (!phaseChanged) return;` guard at
  line 96 exist exactly as described. Capturing `ts` after that guard is the right
  spot — it runs once per confirmed transition for both direct and pending paths.
- Direct path call at line 102 and pending flush call at line 109 are the only two
  call sites (verified by grep across `lib/` and `packages/`).
- Record-type change `_pendingInstruction` `BreathSessionState?` → `(BreathSessionState state, int ts)?`:
  field declared at line 21. Note the implementation detail for `_flushPending`
  (lines 105–110): after the change, the current accessors `pending.phase.name` and
  `pending.currentPhaseTotalDuration * pending.currentIntervalMs` must become
  `pending.state.phase.name` / `pending.state.currentPhaseTotalDuration * pending.state.currentIntervalMs`.
  The plan already calls this out ("read `pending.state` for phase/durationMs") — just
  flagging it so the implementer does not miss the `.state` indirection on the
  duration expression.
- `reset()` at line 119 clears `_pendingInstruction = null` — assigning `null` to a
  nullable record type is valid Dart, no type change needed there. Plan is correct.

**Task 3 — test fake signature** ✅
- `_FakeInstructionStream.sendSample` confirmed at line 55 (`implements
  BreathModuleInstructionStream` via `noSuchMethod`), the only implementer/override.
- All `sendSampleCalls` assertions across the suite (Phases 9–12) use 3-tuples
  `('sid', 'phase', durationMs)`. Keeping the fake recording the same 3-tuple while
  adding the `int timestampMs` parameter to the override keeps every existing
  `expect(...)` compiling and passing unchanged. Confirmed — no assertion reads a
  4th element.

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** No boundary violations. The change stays
  entirely within the domain layer (`lib/BreathModule/Core/`); no domain model leaks
  into a package, no DI/App.dart wiring touched. WARN: none.
- **Rules (`RULES.md`):** No conflict. The three rules concern Module Service
  statelessness, App.dart purity, and constructor injection — none apply to this
  internal timestamp-threading change. WARN: none.
- **Roadmap (`ROADMAP.md`):** Linked. Plan corresponds to line 139 and spec note 104.
  Note: ROADMAP line 147 ("Collapse `BreathModuleInstructionStream` to a thin
  mapper") explicitly flags coordination with note 104 since both touch the
  `sendSample` timestamp — that is a future task and does not block this plan, but
  the implementer of 147 will need to preserve this event-time behavior. No action
  required here. WARN: none.

## Observations (non-blocking)

1. **No test coverage for the actual fix behavior.** With `Testing: no` and Task 3
   limited to signature maintenance, nothing asserts that the captured `ts` is
   threaded through (direct or flush path). This is consistent with the plan's
   settings and the manual verification step, but it means the regression is only
   caught by the manual `session_stream_samples` check. Acceptable given scope; worth
   being aware of. If desired later, recording the 4-tuple in the fake and asserting
   the flush path reuses the buffered `ts` (rather than re-reading the clock) would
   lock in the behavior cheaply.

2. **Duration expression indirection** (covered above) is the single easy-to-miss
   mechanical detail when converting `_flushPending` to the record type. The plan's
   wording covers it; just be deliberate during implementation.

## Positive Notes

- Scope discipline is excellent: the plan explicitly fences off `_canSendNow`, the
  buffer, readiness/eager-open, `durationMs`, and the biometric path — matching the
  "timestamp-source only" guard from note 104.
- Dependencies between tasks are correctly ordered (Tasks 2 and 3 depend on Task 1).
- Capturing `ts` once after the `phaseChanged` guard cleanly unifies direct and
  pending paths so no future buffering reintroduces the skew — exactly the intent.

PLAN_REVIEW_PASS
