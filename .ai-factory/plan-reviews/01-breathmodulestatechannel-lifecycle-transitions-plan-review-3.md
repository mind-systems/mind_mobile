# Plan Review (Round 3): BreathModuleStateChannel — lifecycle transitions

**Plan:** `01-breathmodulestatechannel-lifecycle-transitions.md`
**Target SUT:** `lib/BreathModule/Core/BreathModuleStateChannel.dart`
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)**: file not present → `WARN`.
- **Rules (`.ai-factory/RULES.md`)**: present. Three rules (stateless module services, App.dart purity, constructor injection) — none apply to a test-only deliverable for a coordinator class. No violations.
- **Roadmap (`.ai-factory/ROADMAP.md`)**: test-only change; milestone linkage not material.
- **Skill-context (`.ai-factory/skill-context/aif-review/SKILL.md`)**: not present.

## Round-2 issues — resolution audit

| # | Round-2 finding | Status in v3 |
|---|---|---|
| C1 | Task 8, bullet 4 asserted `channel.pause` on a path the SUT cannot dispatch | ✅ Fixed — the impossible bullet is removed. Task 8 now has 4 bullets; the former bullet 4 is replaced by a liveness assertion that observes a `start()` (a path the SUT can actually take). Notes explicitly explain why the short-circuit clear is not directly observable through fake call counts. |
| I1 | Mismatch between Task 7 Notes and case list re: post-dispose silence | ✅ Fixed — Task 7 Notes now say the silence assertion is covered by a single dedicated case (bullet 6), with reasoning. Notes and case list are consistent. |
| M1 | Subscription-liveness case overlap with bullet 1 | ✅ Fixed — Task 8 Notes now require the liveness test to re-use the same `stateCtrl` from the pre-reset phase within a single test body. The case name now states "on the same stateCtrl after reset", making the liveness aspect observable. |
| M2 | `complete → pause → complete` framed as conditional | ✅ Fixed — Task 5 Notes now explicitly require the case unconditionally, with the right rationale (unit test drives the stream directly). |
| M3 | `_FakeChannel.state` getter / broadcast / no seed | ✅ Fixed — Task 1 Notes pin both: `broadcast()` controller, no seeded events, with rationale tied to the SUT's initial-`_moduleSessionId` assumption and a forward-compatibility note for the instruction-stream follow-up. |
| M4 | `_state` helper `remainingTicks` default undocumented | ✅ Fixed — Task 1 Notes now flag both `currentIntervalMs: 4000` and `remainingTicks: 0` as lifecycle-only defaults to revisit. |

All round-2 findings are addressed.

## Critical Issues

None.

## Important Issues

None.

## Minor Issues

### m1. Pause branch's `!_ended` gate is not exercised

Task 4 Notes correctly identify that the `_started` half of `_started && !_ended` in the pause branch is unreachable for the "never started" case. The Notes are silent on the `!_ended` half, which **is** reachable via an exotic-but-legal-in-unit-test sequence:

`breath → complete (_started=true, _ended=true, _previousStatus=complete) → breath (no dispatch, _previousStatus=breath) → rest (no dispatch, _previousStatus=rest) → pause`

At the final pause: `wasActive=true, status=pause, _started && !_ended` → `_ended=true` blocks dispatch.

This is the only branch in `_handleLifecycle` not exercised by any test in the plan. Adding a single case to Task 4 (e.g. `should not call channel.pause after a pause emission that follows a complete-then-reactivate sequence (because _ended remains true)`) would close the gap. Low priority — it's a defensive guard against a sequence the real state machine almost certainly doesn't produce — but the analogous `_ended` gate in the `complete` branch *is* tested (Task 5 bullet 6), so the asymmetry is worth noting.

### m2. `_FakeChannel` must implement all public members of `ModuleStateChannel`, not just the dispatch methods

`_FakeChannel implements ModuleStateChannel` will require the fake to (statically) satisfy every public member of `ModuleStateChannel`: `state`, `events`, `currentState`, `isConnected`, `start`, `pause`, `unpause`, `end`, `stop`, `dispose`. Routing through `noSuchMethod` handles this dynamically, but the analyzer will only allow that if the class explicitly declares `dynamic noSuchMethod(Invocation invocation)`. Task 1 implies this ("routes anything else through `noSuchMethod` so the fake compiles") but does not name `dispose`, `events`, `currentState`, or `isConnected` as members that will be intercepted. Worth one line of guidance — implementers occasionally forget the `noSuchMethod` declaration is required and produce a class with dozens of analyzer errors.

Same caveat applies to `_FakeInstructionStream implements BreathModuleInstructionStream` (must also intercept `flushBuffer` and `dispose`).

### m3. Constructor sessionId assertion in Task 2 bullet 2 is plausible but ambiguous

Task 2 bullet 2 says:

> `should call channel.start with ActivityType.breath and the constructor sessionId when transitioning from pause to breath for the first time`

Walking the SUT: a first-emission `pause` runs through `_handleLifecycle`, doesn't dispatch (wasPaused=true via null branch, isActive=false), and sets `_previousStatus=pause`. The second emission `breath` then hits wasPaused (pause branch this time) && isActive, `!_started`, and dispatches `start()`. So the test is correct. Worth noting in the case body (or in Task 2 Notes) that this scenario specifically drives **two** emissions where bullet 1 drives only one — otherwise an implementer may collapse the two bullets when they look semantically identical.

## Positive Notes

- All round-2 findings (one critical + one important + four minor) are addressed with substantive Notes, not just renamed test cases. The new Task 8 Notes block — explaining why the short-circuit reset is not directly observable through fake call counts — is exemplary: it documents a non-test that would otherwise look like a coverage gap.
- The `complete → pause → complete` case in Task 5 is now committed unconditionally with the right justification (unit test drives the stream directly), closing the only reachable `_ended`-gate behavior in the `complete` branch.
- Phase 6 (`dispose()`) covers all three observable branches of `_started && !_ended` plus the unconditional `_stateSub.cancel()`. No gaps.
- Phase 7 (`reset()`) factors the three observable consequences (start-not-unpause, no-end-without-start, subscription liveness) and explicitly documents the one non-observable consequence (`_previousStatus = null` clear), preventing future reviewers from re-raising it as a gap.
- Scope discipline is preserved — instruction-stream paths and pending-flush remain explicitly deferred, with forward-compatibility hooks (`_FakeChannel` no-seed note, `_state` helper scoping note) for the follow-up plan.

## Recommendation

The plan is ready to implement. The three minor items above are polish — implementers can fold them in during writing, or defer to a follow-up. No blocking issues.

PLAN_REVIEW_PASS
