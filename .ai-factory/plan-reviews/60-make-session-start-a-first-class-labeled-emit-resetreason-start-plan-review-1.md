# Plan Review: Make session start a first-class labeled emit (`ResetReason.start`)

**Plan:** `60-make-session-start-a-first-class-labeled-emit-resetreason-start.md`
**Files Reviewed:** 6 (state model, state machine, view model, both animation coordinators, state channel) + tests + roadmap
**Risk Level:** 🟢 Low

## Verdict

The plan is technically sound and unusually precise. Every line-number reference checks
out against the current source, the architectural understanding is correct, and the
backward-compatibility reasoning (equality method, `copyWith ??` semantics, restart
re-arming) is accurate. No migrations are involved (Flutter, no DB schema touched) and
there are no security implications.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)** — present. The change respects the module
  boundary: `ResetReason` lives in `packages/breath_module`, consumed by raw-stream animation
  coordinators inside the same package. No domain model leaks into the package; the optional
  Task 5 stays in `lib/BreathModule/`. **No issues.** ✅
- **Rules (`.ai-factory/RULES.md`)** — present, no rules touching enums/switch/animation/logging
  that this plan would violate. **No issues.** ✅
- **Roadmap (`.ai-factory/ROADMAP.md`)** — milestone is present and active (line 185), with a
  matching spec note (`notes/125`). Plan is correctly linked to the roadmap item. ✅

## Verification of Plan Assumptions (all confirmed)

- **Task 1** — `enum ResetReason { newCycle, rest, exerciseChange }` is at `BreathSessionState.dart:7`,
  shared by both `BreathSessionStateMachineState.resetReason` and `BreathSessionState.resetReason`.
  Single definition. Adding `start` as the first variant is safe: no code reads `ResetReason.index`,
  and the enum is never serialized/persisted (it is a transient animation signal excluded from
  equality). Confirmed.
- **No exhaustive-switch breakage.** Searched all `ResetReason` usages: every consumer compares with
  `==` (`BreathAnimationCoordinator`, `OrbAnimationCoordinator`). There is **no `switch` on `ResetReason`**
  anywhere, so adding a variant cannot trigger a non-exhaustive-switch compile error. This is the most
  common failure mode when extending a Dart enum, and the plan is clear of it.
- **Task 2** — `resume()` is at line 182 and is the **only** transition from `pause` → `breath`/`rest`
  (guarded by `if (_state.status != BreathSessionStatus.pause) return;`). The internal counters live at
  lines 80–82, so `bool _hasStarted = false;` fits there. The emit already carries
  `currentIntervalMs: tickService.nominalIntervalMs` seeded at init (lines 151/127). Keeping the full
  constructor (not `copyWith`) is correct since `copyWith` cannot clear `resetReason` to null on
  subsequent resumes. Confirmed.
- **Restart re-arming** — `_setupEngine` (VM line 143) constructs a brand-new
  `BreathSessionStateMachine`, so `_hasStarted` resets to `false` automatically; no reset plumbing
  needed. The VM maps `engineState.resetReason` through in both `_setupEngine` (line 163) and
  `_onEngineState` (line 200). Confirmed.
- **Task 3** — `_onStateChanged` routes `resetReason != null` into `_handleReset` and returns early
  (line 85). The shape selector (lines 54–58) defaults non-`exerciseChange`/`rest` reasons to
  `currentExerciseShape`, so `start` already falls through correctly; making it explicit is sound.
- **Task 4** — `OrbAnimationCoordinator._handleReset` routing (line 96) and the `rest`-snap branch
  (line 60) behave as described; `start` skips the snap and animates from enriched fields. Confirmed.
- **Task 5** — `!_started` discriminator (line 77) and the `_started` instruction gate (line 111) are
  exactly as described; the `ResetReason` import would need adding to the show-list at line 8.

## Findings

### Minor — note, not blocking

1. **Double shape-morph on the first `start` emit (Task 3).** On the first ready emit, the
   `BreathAnimationCoordinator` runs `_handleFirstReady` (which calls
   `shapeShifter.morphToImmediate(nextExerciseShape)`) and *then*, because `start` is now non-null,
   falls into `_handleReset` (which calls `shapeShifter.morphTo(currentExerciseShape)`). Both fire on
   the same emit. For an exercise with steps, `_computeEnrichedFields` sets
   `nextExerciseShape == currentExerciseShape == currentExercise.shape`, so the second `morphTo` targets
   the shape just set — effectively a no-op morph. Harmless, and the plan explicitly says to keep
   `_handleFirstReady` intact, so it is aware of this. No action required, but the implementer should
   confirm `morphTo(sameShape)` does not kick off a visible re-animation in `BreathShapeShifter`. The
   same redundancy (benign) applies to `OrbAnimationCoordinator`'s double `_updateMaxProgress`.

2. **New origin behavior: `motionEngine.resetPosition(0.0)` now runs on first start (Task 3).**
   Previously the first `resume` (resetReason null) went through the activity branch and did **not**
   call `resetPosition`. Routing `start` into `_handleReset` adds `resetPosition(0.0)` at session
   origin. This is the *intended* "initialize at origin" behavior of the milestone, not a regression —
   but it is a genuine behavior change, so it deserves a quick manual smoke check that the orb/motion
   does not visibly jump at the first play tap. Worth a one-line mention in the implementation summary.

3. **Rest-only first exercise.** If the first exercise `isRestOnly`, the `start` emit has phase `rest`
   and status `rest`. In `BreathAnimationCoordinator._handleReset`, `setActive(status == breath)` → false.
   In `OrbAnimationCoordinator._handleReset`, `start` is not `rest`, so it skips the snap branch and hits
   the "not an animated phase → freeze" fallback (orb stays at `_kMinProgress`). Functionally equivalent
   to the pre-change behavior. No issue, but the implementer should be aware the `start` path for a
   rest-only opener intentionally does **not** take the `rest` snap branch.

4. **Task 5 caution is well-placed.** Swapping the start discriminator to `resetReason == start` while
   the `_started` flag still gates instruction sending (`_handleInstruction`, line 111) means
   `_started = true` must still be set somewhere — the two concerns are entangled. The plan correctly
   marks Task 5 optional and permits skipping it. Recommend skipping it in the first pass and recording
   that decision, exactly as the plan suggests; the milestone value is fully delivered by Tasks 1–4.

### Tests

Settings say "Testing: no", and the plan adds none. I verified the **existing** suite stays green:
`breath_session_enriched_state_test.dart` calls `sm.resume()` as the first activation in many tests,
but every assertion on `resetReason` either occurs after an intervening tick (which re-emits `null` or
another reason, clearing `start`) or after a *second* resume (where `_hasStarted` is already true). The
"single emit per tick" tests subscribe *after* `resume()` and clear the buffer, so the `start` emit is
never counted. No existing test asserts that the first `resume()` emits `resetReason == null`. **No test
breakage expected.**

### Logging

Settings say "minimal". `resume()` currently emits no debug log, and the plan adds none — consistent.
The existing `kDebugMode` transition logs in `_startRest`/`_startNewCycle` are left untouched. Fine.

## Positive Notes

- Line-number accuracy across six files is exact — rare and valuable for a smooth implementation.
- Correctly identifies that `resetReason` must **not** be added to `equalsIgnoringTickFields` (it is a
  raw-stream-only signal; adding it would wrongly classify clear-emits as structural changes).
- Correctly preserves the full-constructor emit in `resume()` instead of reaching for `copyWith`, which
  cannot clear the field on later resumes.
- Correctly reasons that restart re-fires `start` for free via fresh state-machine construction, and
  explicitly forbids adding reset plumbing — avoiding a class of dead code.
- Commit plan is clean and maps to safe checkpoints (enum+emit, then consumers, then optional channel).

## Conclusion

The plan is solid, low-risk, and ready to implement. The findings above are advisory (manual smoke
check of the first-tap animation, and the recommendation to skip Task 5 on the first pass) rather than
corrections to the plan.

PLAN_REVIEW_PASS
