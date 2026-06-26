# Code Review: Extract the owned lifecycle FSM, remove `_hasStarted`

**Plan:** `09-extract-the-owned-lifecycle-fsm-remove-hasstarted.md`
**Files reviewed (in full):**
- `packages/breath_module/lib/src/BreathSession/BreathLifecycleMachine.dart` (new)
- `packages/breath_module/lib/src/BreathSession/BreathSessionStateMachine.dart` (modified)
- `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart` (modified)
- Cross-checked: `BreathSessionViewModel.dart` (untouched, confirmed it only reads `engineState.lifecycle`)

**Risk level:** 🟢 Low — pure, behavior-preserving refactor.

## Verdict

The change is correct, compiles cleanly, and is behavior-preserving. The implementation matches the plan exactly. Verified by direct reasoning and by execution.

## Correctness analysis

### Tick-gate equivalence (the only non-trivial behavioral claim)
Old gate: `if (status == pause || status == complete) return;`
New gate: `if (!_lifecycle.isRunning) return;`

These are equivalent because the engine maintains the invariant **`lifecycle == running ⇔ status ∈ {breath, rest}`** at every point a tick can be processed:
- `lifecycle` is mutated only in `resume()` (`run()` → running, paired with a `breath`/`rest` emit), `pause()` (`pause()` → paused, paired with a `pause` emit), and `complete()` (→ completed, paired with a `complete` emit + subscription cancel).
- The initial states (`_initialBreathState`/`_initialRestState`) both emit `status: pause` and the machine defaults to `notStarted` — so pre-resume ticks are dropped by both gates.
- Progression emits (`_onBreathTick`/`_onRestTick`/`_startRest`/`_startNewCycle`/`_advanceExercise`) never touch `lifecycle`; they only run while already `running`, emitting `breath`/`rest`.

No reachable state has `status ∈ {breath, rest}` with `lifecycle != running`, nor `status ∈ {pause, complete}` with `lifecycle == running`. The retained `switch (_state.status)` below the gate still correctly selects breath-vs-rest progression.

### `_emit` ordering (the plan-review's flagged risk)
The plan-review warned that every lifecycle mutation must run **before** `_emit` so the correct value is stamped. Confirmed correct in code:
- `resume()`: `_lifecycle.run()` is called *before* `_emit(...)`, and the old trailing `_hasStarted = true;` was deleted (not relocated). The first-resume `ResetReason.start` is computed from `_lifecycle.isNotStarted` *before* `run()` flips it. ✓
- `pause()`: `_lifecycle.pause()` precedes the emit. ✓
- `complete()`: `_lifecycle.complete()` precedes the emit. ✓

### Behavioral parity with the old `_lifecycleFor`
- Pre-resume pause → `pause()` no-ops on `notStarted` → stamps `notStarted` (old: `!_hasStarted` → notStarted). ✓
- First resume → `start` reason + `running`. Warm resume → `null` reason + `running`. ✓
- Manual pause after resume → `paused`, `isLive` stays true (keep-alive window). ✓
- `complete()` from any state → `completed` (matches old `_lifecycleFor(complete)` which ignored `_hasStarted`). ✓
- `resume()`/`pause()` after `complete()`: `resume()` early-returns on `status != pause`; `pause()` early-returns on `status == complete`. `run()`/`complete()` are also defensively idempotent on `completed`. ✓
- Restart stays a rebuild: `restartEngine` → `_setupEngine` → new `BreathSessionStateMachine` → fresh `BreathLifecycleMachine` at `notStarted`. No `completed → notStarted` self-transition was added, as required. ✓

### Edge cases checked
- No dangling references: `grep` confirms `_hasStarted` and `_lifecycleFor` are fully gone from production code (remaining mentions are only in plan/note/test-comment text, which are not assertions).
- `BreathLifecycleMachine` is pure Dart — no Flutter/Riverpod imports — honoring the domain-layer rule. Correctly left un-exported from the package barrel (internal `lib/src/` collaborator).
- The dartdoc reference `[BreathLifecycleMachine]` added in `BreathSessionState.dart` resolves cleanly (analyzer reports no unresolved-doc-reference).

## Verification performed
- `flutter analyze` on all 3 changed files → **No issues found!**
- `flutter test` on the three acceptance suites (`breath_lifecycle_islive_test.dart`, `breath_session_state_machine_test.dart`, `breath_activity_boundary_characterization_test.dart`) → **All 19 tests passed**, with no assertion edits.

## Findings
None.

REVIEW_PASS
