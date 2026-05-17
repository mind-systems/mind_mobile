# Plan Review: BreathModuleStateChannel — lifecycle transitions

**Plan:** `01-breathmodulestatechannel-lifecycle-transitions.md`
**Target SUT:** `lib/BreathModule/Core/BreathModuleStateChannel.dart`
**Risk Level:** 🟡 Medium

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)**: file not present → `WARN` (no architectural gate available; skipped).
- **Rules (`.ai-factory/RULES.md`)**: present. Rules cover stateless services / DI / App.dart purity — none of them apply to test scaffolding for a domain coordinator class. No violations detected.
- **Roadmap (`.ai-factory/ROADMAP.md`)**: not explicitly checked for linkage; this is a `test`-only change, so milestone alignment is not material.
- **Skill-context (`.ai-factory/skill-context/aif-review/SKILL.md`)**: not present — no project-specific overrides to apply.

## Critical Issues

None — the plan will produce a working test file. Issues below are correctness-of-reasoning and coverage gaps that should be fixed before implementation, but they are not blocking architectural mistakes.

## Important Issues

### 1. Wrong attribution in Task 4: `_started` guard is unreachable in the `pause` branch

> `should not call pause when the session has never been started (_started=false guards the call)`

This claim is wrong. The `pause` dispatch branch is:

```dart
} else if (wasActive && status == BreathSessionStatus.pause) {
  if (_started && !_ended) { _channel.pause(); }
}
```

`wasActive` requires `_previousStatus` to be `breath` or `rest`. The only paths that set `_previousStatus` to an active value are inside `_onState`, **after** `_handleLifecycle` has already toggled `_started = true` on that same call. There is no ready emission sequence in which `wasActive=true && _started=false` can be observed (the non-ready filter at line 45 also blocks `_previousStatus` updates, so it can't sneak `wasActive=true` past). The inner `_started` check is effectively defensive dead code; the actual gate is `wasActive`.

Action: either (a) rename the case to `should not call pause when no prior active state has been observed (wasActive=false short-circuit)` and drop the `_started` rationale, or (b) keep the test name but acknowledge it does not exercise the named guard.

### 2. Wrong attribution in Task 5: `_ended` guard does not prevent the "second `complete`" case

> `should not call channel.end on a second complete emission (_ended guard prevents duplicate end)`

The duplicate `complete` emission is short-circuited at line 54: `if (status == _previousStatus) return;`. Control never reaches the `_ended` check. The `_ended` guard would only matter for `complete → X → complete` transitions, which the state machine does not appear to produce.

Action: rename to `should not call channel.end on a second complete emission (status-unchanged short-circuit)`, OR add a dedicated test that drives `complete → pause → complete` (if such a sequence is even legal) to exercise the actual `_ended` gate. Otherwise the named guard is untested.

### 3. Missing coverage of `stop()` via `dispose()`

The plan's Context section explicitly lists `stop` among the dispatched commands ("`start`, `unpause`, `pause`, `end`, `stop`"), yet no task tests it. `dispose()` calls `_channel.stop()` iff `_started && !_ended`, with three observable branches:

- not started → no stop
- started, not ended → stop
- started and ended → no stop

These are lifecycle-half behavior and should be covered. Add a task (e.g. Phase 6) with at least these three cases. The fake already needs to expose `stopCount`.

### 4. Missing coverage of `reset()`

`reset()` clears `_started`, `_ended`, and `_previousStatus`. It directly determines whether the next emission produces `start()` (vs `unpause()`) and whether `end()` can ever fire again. Since the plan's framing is "lifecycle transitions", reset belongs here. Suggested cases:

- after `reset()`, the next `breath` emission calls `start()` again (not `unpause()`).
- after `reset()`, a `complete` emission with no fresh `start` does not call `end()`.

### 5. Missing test for active → active transitions

`breath → rest` and `rest → breath` should produce **no** lifecycle command (not `start`, not `unpause`, not `pause`). The current code handles this implicitly (the branches don't match), but it's a notable invariant worth one assertion. Suggest adding to Task 3.

## Minor Issues

### 6. `_FakeInstructionStream` construction is under-specified

`BreathModuleInstructionStream`'s constructor requires `instructionStream: ModuleInstructionStream` (non-optional). A subclass cannot avoid calling `super(...)` with a concrete `ModuleInstructionStream` — so "subclass" implies you still need a fake `ModuleInstructionStream` underneath, doubling the surface to stub.

Cleaner: declare `class _FakeInstructionStream implements BreathModuleInstructionStream` and route everything except `sendSample` through `noSuchMethod`. This mirrors what the plan already does for `_FakeChannel`. Recommend pinning this choice explicitly in Task 1 so the implementer doesn't get stuck on the constructor.

### 7. Parenthetical breadcrumbs inside test names

Task 4 contains:

> `should not call pause when a non-ready loadState pause emission arrives (covered indirectly here, fully exercised in Phase 5)`

The parenthetical is meta-commentary, not part of the spec sentence. Move it to a Dart comment or to the task description; otherwise the rendered test report will read awkwardly and CI grep output is harder to scan.

### 8. `_state` helper defaults: `currentIntervalMs`

Default of `4000` is fine for instruction-bearing tests, but `BreathSessionState.initial()` uses `-1`. Since the lifecycle half doesn't read `currentIntervalMs` at all, this is purely cosmetic — but if the same helper is later reused for instruction-stream tests, choosing a positive default may mask off-by-one bugs in the `currentIntervalMs == -1` initial-frame case. Worth a one-line note in Task 1 that this helper is scoped to lifecycle tests and should be revisited when instruction tests are added.

### 9. Test name "treated as start instead, since wasPaused covers _previousStatus == null"

Task 3 bullet 4 is correct in mechanics but the parenthetical explanation reads as a code comment leaking into a test name. Same fix as #7 — move to a comment.

## Positive Notes

- The plan correctly identifies the `_previousStatus` non-update behavior under the `loadState != ready` filter (Task 6, case 4 and 5) — that is the subtlest correctness property of `_onState` and it's exercised properly.
- The split across five phases mirrors the actual branch structure of `_handleLifecycle`, which makes failure attribution easy.
- Using hand-rolled fakes with `noSuchMethod` (Task 1) is the right call for `ModuleStateChannel` — that class has too many internal fields to mock cleanly with Mockito, and a `BehaviorSubject`-seeded `state` stream isn't required by the SUT (only `Stream<ModuleState>`).
- The plan correctly recognizes that `_previousStatus == null` is the "initial pause" case (Task 3, bullet 4) and tests start-on-first-rest as well as start-on-first-breath.
- Scope discipline is good: instruction-stream and pending-flush behavior are explicitly out of scope, which keeps this plan focused.

## Recommendation

Address issues #1–#5 (correctness of reasoning + `stop`/`reset` coverage gaps) before implementing. Issues #6–#9 are polish and can be folded in during implementation.
