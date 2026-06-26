# Code Review: Activity-boundary characterization golden master (current behavior)

## Scope
Reviewed `git diff HEAD` / `git status`. The only **code** change is one new test file:
`test/BreathModule/Support/breath_activity_boundary_characterization_test.dart` (251 lines).
Other diffed files are AI-factory artifacts (ROADMAP, plan, plan-review, plan JSON) — not code.

No production source was modified, consistent with the plan's "no prod change" guard.

## Verification performed
- Read the new test file in full plus all production code it exercises: `BreathSessionStateMachine.dart`, `BreathSessionViewModel.dart`, `BreathSessionState.dart`, the harness (`BreathActivityHarness.dart`), and the fakes (`BreathActivityFakes.dart`).
- Hand-traced the state machine for the two-exercise restart case (4 ticks → `_advanceExercise` to ex1; 4 more → clamp + `complete()` at `exerciseIndex=1, remainingTicks=0`; `restartEngine` → fresh `_setupEngine` → `pause/exerciseIndex=0/remainingTicks=2`; `_hasStarted` re-armed). Matches the assertions exactly.
- Ran the suite: `flutter test test/BreathModule/Support/breath_activity_boundary_characterization_test.dart` → **+5 All tests passed**, green against unmodified production code.

## Correctness notes (all confirmed sound)
- `expectState` sentinel pattern (`const _unset = Object()` + `identical(...)`) correctly distinguishes "assert `resetReason == null`" from "don't check `resetReason`". Const-object identity is stable across calls.
- `harness.states` captures every emission because `vm.stream` (`set state`, `BreathSessionViewModel.dart:108-115`) always calls `_stateController.add` — the `equalsIgnoringTickFields` dedup only gates Riverpod `super.state`. So the `states.length`-unchanged probe for ignored ticks is valid.
- The extra `await pumpEventQueue()` in `setUp` correctly flushes the async broadcast delivery of the initial `_setupEngine` emission, so `states.first` is reliably the anchor state.
- Task 3's nested `setUp` disposes the outer default harness before replacing it with the two-exercise one, and the outer `tearDown` disposes the reassigned `harness`. No double-dispose, no leak.
- Assertions stay strictly on the current schema fields (`status`/`phase`/`exerciseIndex`/`resetReason`/`remainingTicks`) — the `lifecycle`/`isLive` guard is respected.
- File is correctly named `*_test.dart` (picked up by the runner); the sibling `BreathActivityHarness.dart` is not, so it won't be mis-run.

## Non-blocking observation (not a defect)
- In the Task 3 group, the outer `setUp` builds and `init()`s a default single-exercise harness that the nested `setUp` immediately disposes and replaces. This is harmless wasted setup, not a correctness issue. Left as-is is fine; the shared `setUp`/`tearDown` symmetry is arguably clearer than special-casing.

## Conclusion
No bugs, security issues, or correctness problems. Test-only, behavior-characterizing, green now. Nothing will break at runtime — there is no production surface in this change.

REVIEW_PASS
