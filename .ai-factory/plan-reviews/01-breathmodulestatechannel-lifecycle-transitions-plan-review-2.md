# Plan Review (Round 2): BreathModuleStateChannel — lifecycle transitions

**Plan:** `01-breathmodulestatechannel-lifecycle-transitions.md`
**Target SUT:** `lib/BreathModule/Core/BreathModuleStateChannel.dart`
**Risk Level:** 🟡 Medium → 🟢 Low (one remaining correctness bug in a test case)

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)**: file not present → `WARN`.
- **Rules (`.ai-factory/RULES.md`)**: rules cover stateless services / DI / App.dart purity — none apply to a test-only deliverable. No violations.
- **Roadmap (`.ai-factory/ROADMAP.md`)**: test-only change; milestone linkage not material.
- **Skill-context (`.ai-factory/skill-context/aif-review/SKILL.md`)**: not present.

## Round-1 issues — resolution audit

| # | Round-1 finding | Status in v2 |
|---|---|---|
| 1 | Wrong attribution: `_started` unreachable in pause branch | ✅ Fixed — Task 4 Notes explicitly call this out as defensive/dead code; the test name now attributes to `wasActive=false`. |
| 2 | Wrong attribution: `_ended` does not gate second `complete` | ✅ Fixed — Task 5 Notes correctly attribute the duplicate-complete suppression to `status == _previousStatus`; a separate conditional case for `complete → pause → complete` exercises the real `_ended` gate (with a sensible "drop if state machine cannot produce" guard). |
| 3 | Missing `stop()` / `dispose()` coverage | ✅ Fixed — Phase 6 / Task 7 added; covers all three observable branches plus the "no further lifecycle after dispose" sanity assertion. |
| 4 | Missing `reset()` coverage | ⚠️ Mostly fixed — Phase 7 / Task 8 added, but **bullet 4 makes an incorrect behavioral claim** (see Critical Issue below). |
| 5 | Missing active → active transitions | ✅ Fixed — Task 3 now adds both `breath → rest` and `rest → breath` "no command" assertions. |
| 6 | `_FakeInstructionStream` construction under-specified | ✅ Fixed — Task 1 Notes explicitly pin the `implements` approach and explain why subclassing fails. |
| 7 | Parenthetical breadcrumbs in test names | ✅ Mostly fixed — remaining parentheticals (e.g. "`wasActive=false short-circuits the pause branch`") are now intentional attribution hints rather than meta-commentary. Acceptable. |
| 8 | `_state` helper `currentIntervalMs` default | ✅ Fixed — Task 1 Notes warn the helper is scoped to lifecycle tests and the default should be revisited for instruction tests. |
| 9 | Test name with leaking code comment | ✅ Fixed — rephrased to a clean spec sentence with the rationale moved into the task description. |

## Critical Issues

### C1. Task 8, bullet 4 — claim is physically impossible with the current SUT

> `should call channel.pause when a pause emission follows the same status that was last seen before reset (status-unchanged short-circuit is reset along with _previousStatus)`

Walk the code (lines 53–84 of `BreathModuleStateChannel.dart`) with the proposed scenario `breath → pause → reset() → pause`:

After `reset()`: `_started=false`, `_previousStatus=null`.
On the next `pause` emission:

1. `status (pause) == _previousStatus (null)` → false; the status-unchanged short-circuit does **not** fire (good, the test wants this).
2. `isActive` = `false` (pause).
3. `wasActive` = `false` (null is not breath/rest).
4. `wasPaused` = `true` (null branch).
5. `wasPaused && isActive` → false (no start/unpause).
6. `wasActive && status == pause` → **false** (no pause).
7. `status == complete` → false.

⇒ **No command is dispatched.** The assertion that `channel.pause` is called will fail.

The intent — "demonstrate that the status-unchanged short-circuit is cleared by reset" — is sound, but `pause` is the wrong probe because the pause branch is gated by `wasActive` which requires a prior active emission, and `reset()` wipes that prior. There is no status whose dispatch survives a freshly-reset `_previousStatus=null` except `breath`/`rest` (start) and `complete` is blocked by `!_started`. Bullet 1 already covers the breath case, so bullet 4 is either:

- **Redundant** (re-spell as start, duplicating bullet 1), or
- **Misframed** — should assert *no command is dispatched* on `pause` after reset, since the only observable difference vs. the no-reset case is that the short-circuit early-return doesn't fire (which is itself not directly observable through fake call counts).

**Action:** drop bullet 4, or rewrite it as an inverse assertion — e.g. `should not call channel.pause when a pause emission arrives after reset because wasActive=false (and _previousStatus has been cleared by reset)`. That at least exercises something observable, even if the short-circuit reset itself is non-observable on this status.

## Important Issues

### I1. Task 7 Notes say "all three cases must also confirm" but only one case is written

The Notes block under Task 7 says:

> All three cases must also confirm that subsequent `stateStream` emissions do not produce lifecycle calls after `dispose()` (because `_stateSub.cancel()` runs unconditionally).

…but the test list collapses that into a single case (bullet 6) instead of folding the post-dispose silence assertion into each of bullets 3 / 4 / 5. Either:

- restate the Notes to match — i.e. "**one** dedicated test confirms subscription cancellation across all three branches", or
- expand bullets 3 / 4 / 5 to each append a post-dispose emission and assert no extra call.

The current mismatch is small but will trip up the implementer when they try to follow the Notes literally.

## Minor Issues

### M1. Task 8 bullet 5 partly overlaps bullet 1

> `should keep the stateStream subscription alive across reset, verified by emitting another ready breath after reset and observing the corresponding start call`

This is functionally a stricter version of bullet 1 (which also emits a breath after reset and asserts `start`). The distinguishing intent is "subscription liveness" but the observable signal is identical. Worth keeping if you want the test name to document the contract, but consider noting that the *liveness* aspect can be made explicit by re-using the same `stateCtrl` from bullet 1 (i.e. not creating a fresh fixture) so the test demonstrably proves the subscription survived.

### M2. Task 5 — `complete → pause → complete` conditional case

The "drop if the state machine cannot produce this sequence" caveat is correct, but in a *unit* test driven directly by a `StreamController<BreathSessionState>`, there is no state machine in the loop — the test can emit any sequence regardless of whether the real producer would. Recommend just keeping the test unconditionally: it exercises the `_ended` gate, which is the only branch in `_handleLifecycle` that is otherwise untested. The current "conditional drop" framing risks the implementer deciding to drop it on weak grounds.

### M3. `_FakeChannel.state` getter wiring

Task 1 says the fake exposes `Stream<ModuleState> get state => stateController.stream`. Good — that matches the SUT's `channel.state.listen(...)` call in the constructor. Worth pinning that the controller must be `broadcast()` (the plan already says so) **and** that no event is seeded by default — the SUT does not assume an initial `moduleSessionId`, and seeding one would silently change the instruction-path tests later. Worth a one-liner in the Notes to lock this down for the instruction-stream follow-up plan.

### M4. `_state` helper does not document `remainingTicks` default

Task 1 says `_state(...)` provides "sensible defaults for the remaining required fields (`remainingTicks: 0`)". Fine for lifecycle tests, but the same default-helper convention will spill into the instruction-stream tests, where `remainingTicks` may matter for boundary cases. Same flag as the `currentIntervalMs` warning — fold into the existing scoping note.

## Positive Notes

- Round-1 attribution errors (issues #1, #2) are cleanly corrected in v2 with explicit Notes that name the *actual* gate for each branch. The Notes block under Task 4 in particular is a model example of distinguishing the real gate (`wasActive`) from the defensive dead code (`_started`).
- The new Phase 6 (`dispose()`) maps directly onto the three observable branches of `_started && !_ended`, with no missing combinations.
- The new Phase 7 (`reset()`) correctly factors the three observable consequences (start-not-unpause, no-end-without-start, short-circuit reset) — even though one case (C1 above) misfires on the third consequence.
- Scope is still tight: instruction-stream and pending-flush behaviour are explicitly deferred. The lifecycle/instruction split keeps each plan reviewable.
- The fake design (Task 1) is now unambiguous: `implements` + `noSuchMethod` for both fakes, with the rationale for not subclassing `BreathModuleInstructionStream` spelled out.

## Recommendation

One critical issue (C1) must be addressed before implementation — the test as written cannot pass against the current SUT, and the only valid interpretations are either dropping it or inverting its assertion. Issues I1 and M1–M4 are polish; fold them in during implementation or in a follow-up.

Address C1, then proceed.
