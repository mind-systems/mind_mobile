# Plan Review 2: Retire the derived `status` from `BreathSessionState`

**Plan:** `10-retire-the-derived-status-from-breathsessionstate.md`
**Files Reviewed:** 14 source/test files + plan
**Risk Level:** 🟢 Low — the one critical error from review 1 is fixed; every remaining mapping, path, and line reference verified accurate.

## Re-verification against review 1

Review 1's single Critical Issue (golden-master `pause` sites at ~L173 and ~L214 wrongly mapped to `paused`) is now **resolved** in this revision:

- **Trap 1** (plan lines 28–35) now gives the correct per-site answer key: ~L73 → `notStarted`, ~L106/107 → `paused`, ~L173 (post-`restartEngine`) → `notStarted`, ~L214 (case A, never resumed) → `notStarted`.
- **Task 5** (plan line 95) repeats the corrected mapping and explicitly warns *"Do not write `paused` at ~L173 or ~L214."*

I re-confirmed the four sites in `breath_activity_boundary_characterization_test.dart`: L73 (initial smoke), L106 (`pause()` after the `resume()` at L92), L172 (after `harness.restartEngine()` at L167), L214 (case A, default harness never resumed). The new mapping matches the engine's actual emissions — `restartEngine()` builds a fresh `BreathSessionStateMachine` whose `BreathLifecycleMachine` starts at `notStarted` (confirmed in `BreathLifecycleMachine.dart`), and the never-resumed harness early-returns in `_onTick` (`if (!_lifecycle.isRunning) return;` at L246). No remaining golden-master error.

## Scope & correctness verification (this review)

I cross-checked each task against the source:

- **Task 1 — `BreathSoundCoordinator`** (verified L20, 104, 114, 156–177, 200–204):
  - `_onTick` rewrite `notStarted || paused || (running && phase == rest)` is equivalent to old `pause || rest || (breath && phase == rest)`. The old `(breath && phase==rest)` term was already dead (breath ⟺ phase != rest), so dropping it is safe.
  - `toggleMute` restore: `running && _currentPhase != null && _phaseAssets.containsKey(_currentPhase)` ⟺ old `breath && …` because `_phaseAssets` excludes `rest`, so `running && containsKey` ⟺ `running && phase != rest` ⟺ `breath`.
  - The lifecycle-keyed block-3 / keep-block-4 split preserves behavior on the `breath↔rest` boundaries: those keep `lifecycle == running`, so block 3 is skipped and the existing phase-change block (4) produces the same `fadeOut(500)` (rest, no asset) / `crossfadeTo` (breath, asset) outcomes. Verified equivalent.

- **Task 2 — animation coordinators** (verified `BreathAnimationCoordinator` L46, 85, 101, 127; `OrbAnimationCoordinator` L104): all four `status == breath` reads and the one `status != breath` freeze-guard exist exactly where the plan says. The "actively breathing" expression `lifecycle == running && phase != rest` is the correct equivalent.

- **Task 3 — screen + timeline** (verified `BreathSessionScreen` L250–255, 279–287, 386, 392, 410; `BreathTimelineWidget` L11, 94–98): both `.select` tuples read `s.status`; `_buildControlButton` and `BreathTimelineWidget` both receive `status:`. The `isPaused = lifecycle != running` mapping is sound after the `completed` early-return, and the timeline `isPausedOrComplete` null-preservation note (`paused || notStarted || completed`, null stays false) is correct — the field is nullable only because the old `status` was.

- **Task 4 — state machine** (verified L172, 192, 246–257): `pause()`/`resume()` guards and the `_onTick` switch exist as described. `resume()`'s new guard `if (_lifecycle.isRunning || _lifecycle.current == completed) return;` correctly reproduces old `status != pause` (old `pause` ⟺ lifecycle ∈ {notStarted, paused}). The phase-dispatch (`phase == rest → _onRestTick`, else `_onBreathTick`) is valid because the `!isRunning` gate precedes it and, while running, `phase == rest ⟺ old status == rest`.

- **Task 6 — field/enum removal** (verified `BreathSessionState` L5, 24, 63, 84, 119, 137/159; `BreathSessionStateMachineState` L15, 34, 50/65; 9 emit sites at L125/149/176/201/226/285/322/350/380; `BreathSessionViewModel` L168/205): every removal target exists. Both ViewModel construction sites already set `lifecycle:` alongside `status:`, so dropping `status:` is safe.

- **Task 5 — test migration:**
  - State-channel `_state()` helper (L111–134) currently derives `lifecycle` from `status` via a `switch`; the plan's rewrite to take `lifecycle`+`phase` directly is correct, and the uniform `pause → paused` mapping is justified here (the helper's own doc comment, L104–110, notes the channel treats `notStarted`/`paused` identically). The `status: rest, phase: exhale` case at L963 with assertion `('sid','exhale',5)` at L967 confirms the "carry `phase:` verbatim, never force `rest`" rule. Doc-comment removal (L97–110) correctly flagged as stale.
  - Equality test (`breath_session_state_equality_test.dart`): confirmed base `_state()` sets `status: breath` with `lifecycle` left at default `notStarted` (L31) — the plan's explicit `lifecycle: running` is required. The two full-constructor sites copy `status: a.status` (L74, L100) and omit `lifecycle`, so a naive delete would leave `b.lifecycle == notStarted` and break both tests — the plan's `lifecycle: a.lifecycle` replacement is necessary. The "only status differs" test (L143–147, `copyWith(status: pause)`) correctly becomes `copyWith(lifecycle: paused)`, observable against the `running` base.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** PASS. All changes stay inside `packages/breath_module` presentation/state logic; no domain model crosses the module boundary, no Service/DTO contract changes. Representation-only refactor — no boundary impact.
- **Rules (`.ai-factory/RULES.md`):** PASS. The three rules (stateless Module Services, no module state in App.dart, constructor injection) are untouched by this work.
- **Roadmap (`.ai-factory/ROADMAP.md`):** WARN (informational, non-blocking). The plan carries no explicit roadmap linkage. This is a `refactor` (behavior-unchanged representation cleanup), not `feat`/`fix`/`perf`, so linkage is optional — noted only for completeness.

## Positive Notes

- The revision fully absorbed review 1's correction without introducing drift: both Trap 1 and Task 5 now state the same per-site answer key, eliminating the earlier internal contradiction.
- Sequencing remains correct — enum/field survive through Task 5 so every migrated assertion compiles before the Task 6 deletion; three commits are each independently buildable.
- The subtle equality-test full-constructor trap (silent `notStarted` default breaking `equalsIgnoringTickFields`) and the state-channel "rest carrying a non-rest phase" trap are both caught and handled correctly.
- Every mapping traced is semantically equivalent to the old `status` derivation; the "behavior unchanged — representation only" claim holds.

## Verdict

The plan is accurate, complete, and internally consistent. All file paths, line references, API usages, and equivalence mappings verified against the live code. No blocking issues remain.

PLAN_REVIEW_PASS
