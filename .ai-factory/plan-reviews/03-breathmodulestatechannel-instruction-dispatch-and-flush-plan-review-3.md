# Plan Review: BreathModuleStateChannel — instruction dispatch and flush (Iteration 3)

**Plan file:** `.ai-factory/plans/03-breathmodulestatechannel-instruction-dispatch-and-flush.md`
**Target spec:** `test/BreathModule/breath_module_state_channel_test.dart`
**SUT:** `lib/BreathModule/Core/BreathModuleStateChannel.dart`
**Prior reviews:** review-1 (10 issues), review-2 (2 critical + 4 minor).

## Risk Level: 🟢 Low

Iteration 3 closes every issue raised in review 2. The two critical bugs (Task 3 sub-tests 3 and 4 missing the post-reset re-seed, and Phase 1 sub-test 7's misleading dispatch comment) are both fixed at the test description and reinforced by new entries in the "Important behavioural quirks" preface. All four minor issues are also resolved.

I re-traced every test in Phase 1, Phase 2, and Phase 3 against the SUT
(`lib/BreathModule/Core/BreathModuleStateChannel.dart`) and the existing
fakes/helpers in the spec file. Every assertion holds.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** PASS — plan only extends an existing test file in `test/BreathModule/`; no module-boundary or DI implications.
- **Rules (`.ai-factory/RULES.md`):** not present — gate skipped.
- **Roadmap (`.ai-factory/ROADMAP.md`):** WARN — plan still has no explicit milestone linkage. Acceptable for test-hardening work, carried over from review 2.

## Resolved from Review 2

### Critical
- **Issue 1 (Task 3 sub-tests 3 & 4 fail without re-seed):** ✅ Both sub-tests now contain an explicit "Re-seed: push `ModuleState('sid', active)` onto `f.channel.stateController` and `await Future<void>.delayed(Duration.zero)`" step immediately after `reset()` (plan lines 111, 113). Note 4 in the quirks preface also names these sub-tests as users of the re-seed pattern. The re-traced sequence now yields `sendSampleCalls.length == 2` and `startCalls.length == 2` as asserted.
- **Issue 2 (Phase 1 sub-test 7 incorrect inline comment):** ✅ The parenthetical is rewritten verbatim to the suggested wording: *"this `ready+breath` emission starts the lifecycle but does **not** dispatch, because `_previousPhase` was primed to `inhale` by the prior pause — `phaseChanged` evaluates to `false`"* (plan line 79). The assertion `sendSampleCalls.length == 1` and `sendSampleCalls.last == ('sid', 'exhale', 6000)` is consistent with the re-traced flow.

### Minor
- **Issue 3 (Phase 1 sub-test 6 implementation hint vague):** ✅ Plan line 77 now spells out the assertion sequence: assert `1` after the initial `ready+breath`, assert "still `1`" after the post-complete emission, plus the new `startCalls.length == 1` check. Note 8 (lines 53–54) documents the no-spurious-start contract.
- **Issue 4 (Phase 2 sub-test 5 lifecycle short-circuit undocumented):** ✅ Plan line 97 now contains the inline note about lifecycle short-circuit while `_handleInstruction` still runs, cross-referencing Note 5 (lines 44–45).
- **Issue 5 (Task 4 microtask idiom phrasing):** ✅ Plan line 124 uses the canonical `await Future<void>.delayed(Duration.zero)`, and Note 7 (lines 50–51) codifies the idiom.
- **Issue 6 (`isPaused` field clarification):** ✅ Note 6 (lines 47–48) explicitly says the SUT does not read `isPaused` and instructs the implementer to omit it.

## Verification against the SUT and existing fixtures

I traced the critical re-seed cases against `BreathModuleStateChannel.dart`:

- `_handleInstruction` (lines 86–101): confirmed `isActive = breath || rest`, guarded by `!isActive || !_started || _ended`, `phaseChanged` is the disjunction of phase and exerciseIndex change, and sessionId-null path stores `_pendingInstruction` and returns.
- `_flushPending` (lines 103–108): consumes and clears `_pendingInstruction` then dispatches.
- `reset()` (lines 110–119): clears `_moduleSessionId`, `_started`, `_ended`, `_previousStatus`, `_previousPhase`, `_previousExerciseIndex`, `_pendingInstruction`. Both subscriptions stay alive per the comment.
- `dispose()` (lines 121–128): cancels both `_stateSub` and `_channelSub`.
- The public `moduleSessionId` getter (line 42) exists, supporting Task 4 sub-test 5's verification path.

Re-traced critical test sequences against `_handleInstruction` / `_flushPending` / `_onState` ordering:

- **Phase 1 Task 1 sub-test 1** (primed `ready+pause(inhale)` → `ready+breath(exhale, 5000)`): single dispatch `('sid', 'exhale', 5000)`. ✅
- **Phase 1 Task 1 sub-test 6** (`_ended` guard): 1st dispatch on first `ready+breath`, no dispatch on `complete` (`!isActive`), no dispatch on post-complete `ready+breath` (`_ended=true`); `startCalls.length` stays `1` because no lifecycle branch matches `complete → breath`. ✅
- **Phase 2 sub-test 5** (overwrite pending): second `ready+breath` short-circuits in `_handleLifecycle` but `_handleInstruction` still overwrites `_pendingInstruction`; flush yields the latest `('sid', 'inhale', 6000)`. ✅
- **Phase 3 Task 3 sub-test 3** (with re-seed): re-seeded ModuleState restores `_moduleSessionId='sid'` with `_pendingInstruction=null` after reset (so `_flushPending` is a no-op); post-reset `ready+pause → ready+breath` triggers second start and second dispatch with `currentIntervalMs=5000`. ✅
- **Phase 3 Task 3 sub-test 5** (post-reset subscription survival): construct → `reset()` → push `ModuleState('sid-new')` → prime `ready+pause` → `ready+breath` → exactly one start, dispatch uses `'sid-new'`. ✅
- **Task 4 dispose sub-test** (channel.state subscription cancelled): dispose immediately after construction does NOT call `channel.stop` (because `_started=false`), but DOES cancel `_channelSub`, so subsequent `ModuleState` push must not update the getter; `moduleSessionId` remains `null`. ✅

## Positive Notes

- The "Important behavioural quirks" preface now contains **eight** notes that collectively prevent every mistake an implementer would otherwise make in this surface area (first-emission implicit dispatch, lifecycle-before-instruction order, post-reset `_moduleSessionId` clearing, lifecycle short-circuit with instruction still running, `isPaused` ignored, microtask idiom, post-complete no-spurious-start). The cross-references from individual test descriptions (e.g. "see Note 5", "see Note 8") are an unusually disciplined pattern.
- The plan distinguishes between tests that intentionally rely on first-emission implicit dispatch (Phase 1 sub-tests 4 and 5) and tests that must avoid it (Phase 1 sub-tests 1–3, 7, 8) — the "unless otherwise noted" carve-out in the Phase 1 preamble is honest.
- Task 4 explicitly cites the existing Phase 7 line numbers (571, 582, 597, 622, 636) that already cover the dispose contract, preventing accidental duplication.
- The `currentIntervalMs: -1` case (Phase 1 sub-test 8) anchors against the real initial value rather than a synthetic default — exactly the concern flagged in the existing `_state(...)` helper comment at lines 67–71 of the spec file.

## Nitpicks (non-blocking, no action required)

- Phase 2 sub-tests 5 and 6 use the shorthand `ModuleState(moduleSessionId: 'sid')` without an explicit `status`. The `ModuleState` constructor requires `status`, so the implementer will naturally add `status: ModuleStateStatus.active` (as in Phase 2 sub-tests 2–4). Worth knowing but the implementer cannot accidentally compile without it.

## Summary

All blocking issues are resolved. The plan is implementation-ready: every test description matches a coherent trace through the SUT, every quirk that bit prior iterations is documented in the preface, and the re-seed pattern is consistently applied where `reset()` clears `_moduleSessionId`.

PLAN_REVIEW_PASS
