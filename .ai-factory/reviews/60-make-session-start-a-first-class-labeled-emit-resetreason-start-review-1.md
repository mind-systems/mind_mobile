# Code Review: Make session start a first-class labeled emit (`ResetReason.start`)

**Reviewed:** working-tree diff vs `HEAD` (staged + unstaged)
**Files changed (code):** 4
- `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart`
- `packages/breath_module/lib/src/BreathSession/BreathSessionStateMachine.dart`
- `packages/breath_module/lib/src/BreathSession/Animation/BreathAnimationCoordinator.dart`
- `packages/breath_module/lib/src/BreathSession/Animation/OrbAnimationCoordinator.dart`
- `lib/BreathModule/Core/BreathModuleStateChannel.dart` (Task 5 — optional)

**Verification run:**
- `flutter analyze` on changed files → **No issues found.**
- `flutter test test/BreathModule/Presentation/BreathSession/` → **80 passed.**
- `flutter test test/BreathModule/breath_module_state_channel_test.dart` → **22 passed, 34 FAILED.**

**Risk level:** 🔴 Blocking — Task 5 broke the existing channel test suite.

---

## Findings

### 🔴 BLOCKING — Task 5 breaks 34 channel tests; the suite was left red

`BreathModuleStateChannel._handleLifecycle` was changed (Task 5) to discriminate first-start
from resume using the emit label instead of the internal flag:

```dart
// before
if (!_started) { ... _channel.start(...) ... }
// after
if (state.resetReason == ResetReason.start) { ... _channel.start(...) ... }
```

`test/BreathModule/breath_module_state_channel_test.dart` drives the channel with synthetic
states built by the `_state({...})` helper (line 72), which **never sets `resetReason`** — it
defaults to `null`. Every test simulates the first activation by emitting
`_state(status: BreathSessionStatus.breath)`. Under the old `!_started` logic that triggered the
start branch; under the new label check it does **not**, so `_channel.start()` is never called,
`_started` stays `false`, and all downstream lifecycle/marker/instruction assertions fail.

Result: **34 of 56 tests in this file fail** (e.g. "emits start marker", "session resume after
pause", "reset() clears instruction state" — all show `Actual: []` because no sample was ever
sent). The implementation summary marked Task 5 `[x]` without the suite being green.

This is a hard regression in the checked-in test suite regardless of production behavior, and any
CI gate will fail. It must be resolved one of two ways:

- **Preferred (matches the plan + plan-review):** revert Task 5. The plan explicitly marked it
  *optional and guarded* and said to skip it and record the decision if it isn't clean; the
  plan-review (finding 4) recommended the same. The milestone's value (labeled emit + animation
  consuming it, Tasks 1–4) is fully delivered without touching the channel. Reverting drops the
  `ResetReason` import added at line 8 and restores the `!_started` discriminator.
- **Alternative:** keep Task 5 but update all 34 tests so the first active emit carries
  `resetReason: ResetReason.start` (add the param to the `_state` helper / first-activation call
  sites). This is more churn and locks in the coupling described below.

### 🟡 Concern — Task 5 increases coupling / fragility of session-start detection (the reason to prefer revert)

The old `!_started` discriminator was self-contained: the *first* pause→active transition the
channel observes starts the session, independent of payload contents. The new check makes
session-start depend on `resetReason: start` surviving intact through the VM's raw stream
(`_stateController`, which the channel consumes via `vm.stream`).

In production this currently holds — `BreathSessionStateMachine.resume()` emits `start` on the
first activation, the VM forwards it on the unconditional raw stream (`set state` always calls
`_stateController.add`), and restart re-arms both sides together (`restartEngine()` →
`_onModuleReset()` = `channel.reset()` resets `_started`, and `_setupEngine()` builds a fresh
machine so `_hasStarted` is false again). So I found **no production break** today.

But the failure mode if the label is ever dropped/coalesced is silent and bad: the first active
emit would fall through to the `else` branch and call `_channel.unpause()` on a session that was
never `start()`-ed (and `_started`/stopwatch/origin-wallclock would never initialize). The
self-contained flag had no such failure mode. This is exactly the entanglement the plan-review
flagged, and is the substantive argument for reverting Task 5 rather than just patching the tests.

### 🟢 Tasks 1–4 are correct and safe

- **Task 1** (`enum ResetReason { start, ... }`): single shared definition; no `switch` on
  `ResetReason` exists anywhere (all consumers use `==`), so no non-exhaustive-switch break. Enum
  is never serialized/persisted and stays excluded from `equalsIgnoringTickFields` — correct, a
  new value does not perturb Riverpod publication.
- **Task 2** (`_hasStarted` + `reason = _hasStarted ? null : ResetReason.start`): `resume()` is the
  only `pause → breath/rest` transition; full-constructor emit is preserved (so `null` clears on
  later resumes); `_hasStarted = true` set after the emit; no flag-reset plumbing added (restart
  rebuilds the machine). Carries the seeded `currentIntervalMs` (note 122). Correct.
- **Task 3 / Task 4** (animation coordinators): comment-only changes. `start` already satisfies
  `resetReason != null`, routing into `_handleReset`, and the existing shape ternary already
  defaults non-`exerciseChange`/`rest` reasons to `currentExerciseShape`, so `start` resolves
  correctly. The `BreathSession/` suite (80 tests, incl. restart + orb-resume) stays green.

### 🟢 Notes (non-blocking, informational)

- **`start` path does not call `motionEngine.setIntervalMs`.** Routing `start` through
  `_handleReset` (early return) means the seeded `currentIntervalMs` is not pushed into the motion
  engine at origin; it keeps its `_smoothedIntervalMs = 1000.0` default until the first real tick.
  This matches the *pre-change* first-resume behavior (where `setRemainingPhaseTicks` ran before
  `setIntervalMs`, so the first phase already used the 1000 ms default), and all other reset paths
  behave the same way, so it is **not a regression**. For the heart-rate source (nominal ≠ 1000 ms)
  the first pre-tick phase animates at a slightly off cadence and snap-corrects on the first tick —
  worth a one-line manual smoke check but not required.
- **Double shape-morph on the first `start` emit** (`_handleFirstReady` `morphToImmediate` then
  `_handleReset` `morphTo`) targets the same shape for stepped exercises (`nextExerciseShape ==
  currentExerciseShape`), so it is a benign no-op morph. Confirm `BreathShapeShifter.morphTo(same)`
  does not kick a visible re-animation.
- **`resetPosition(0.0)` now runs at first start** (it did not on the old null-reason first resume).
  This is the intended "initialize at origin" behavior of the milestone; verify no visible orb/motion
  jump on the first play tap.

---

## Conclusion

Tasks 1–4 are implemented correctly and their tests pass. The blocking issue is Task 5: it was the
explicitly-optional, explicitly-discouraged change, and it left **34 channel tests failing** while
being marked complete. Recommend reverting Task 5 (restore `!_started`, drop the `ResetReason`
import) — this matches the plan and plan-review guidance and is the lowest-risk resolution — or, if
Task 5 is kept, updating the 34 tests to emit `resetReason: ResetReason.start` on first activation.
Re-run `flutter test test/BreathModule/breath_module_state_channel_test.dart` until green before
landing.
