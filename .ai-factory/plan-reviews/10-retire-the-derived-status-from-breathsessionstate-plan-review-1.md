# Plan Review: Retire the derived `status` from `BreathSessionState`

**Plan:** `10-retire-the-derived-status-from-breathsessionstate.md`
**Risk Level:** 🟡 Medium — one concrete factual error in the golden-master test migration; everything else verified accurate.

## Scope verification

I cross-checked every file path, API, and line reference in the plan against the live code:

- **All 14 files** referencing `BreathSessionStatus` (grep-confirmed) are covered by the plan's tasks. No consumer is missed.
- **`BreathModuleStateChannel`** (the only `lib/`-side consumer of breath state) **already reads `state.lifecycle` / `state.phase`** and does *not* import `BreathSessionStatus` — so no migration is needed there, and the plan correctly omits it. This was the highest-risk "missing step" candidate and it checks out.
- **Equivalence map** (`pause`/`breath`/`rest`/`complete` → lifecycle+phase) matches the actual emit sites in `BreathSessionStateMachine`. When `lifecycle == running`, `phase == rest ⟺ old status == rest`, confirmed by every emit site (`_onRestTick`/`_startRest` always pair `status: rest` with `phase: rest`; `resume()` derives `status` from `wasResting = phase == rest`).
- **`BreathLifecycleMachine`** exposes `current`, `isRunning`, `isNotStarted` exactly as the plan assumes; no `paused`/`completed` getter exists, and the plan correctly says to compare `current == ...` directly.
- **Export claim (Task 6) is correct:** `breath_module.dart:23` is a whole-file `export 'src/BreathSession/Models/BreathSessionState.dart';` with **no `show` clause**, so deleting the enum needs no export-list edit.
- **`BreathSoundCoordinator` `_onTick` rewrite** is logically equivalent (`notStarted || paused || (running && phase == rest)` covers old `pause || rest || (breath && phase == rest)`).
- **Screen control button & timeline widget** mappings verified: `isPaused = lifecycle != running` is sound after the `completed` early-return; the timeline `isPausedOrComplete` null-preservation note is correct (the field is nullable only because old `status` was).
- **Equality test traps verified line-by-line:** base `_state()` sets `status: breath` with `lifecycle` left at default `notStarted` (line 31) — the plan correctly requires an explicit `lifecycle: running`. The two full-constructor sites (`status: a.status` at L74 and L100) must become `lifecycle: a.lifecycle`, exactly as the plan states. The "only status differs" test → `copyWith(lifecycle: paused)` is observable against a `running` base.

## Critical Issues

### 1. Golden-master test: two `pause` sites are mapped to `paused` but are actually `notStarted`

**File:** `test/BreathModule/Support/breath_activity_boundary_characterization_test.dart`
**Plan locations:** Trap 1 (lines 28–30) and Task 5 (line 90).

The plan instructs: *"Every pause emission after an active `resume()` (~lines 106, 172, 214) → `lifecycle: BreathLifecycle.paused`."* Two of those three sites are wrong:

- **~Line 173 (post-`restartEngine`):** The assertion at lines 170–177 follows `harness.restartEngine()` (line 167). `restartEngine()` → `_setupEngine()` → constructs a **fresh `BreathSessionStateMachine`** whose `BreathLifecycleMachine` starts at `notStarted`. The initial state is set via `_state = _initialBreathState()` (no `_emit`), and `_setupEngine` stamps `lifecycle: initialEngineState.lifecycle == notStarted`. The earlier `resume()` at line 142 is irrelevant — the engine was discarded. **Correct value: `notStarted`.**

- **~Line 214 (case A — "ticks in initial pause (not started)"):** The default harness is **never resumed**; the 3 ticks all early-return in `_onTick` (`!_lifecycle.isRunning`), so `states.last` is still the initial `notStarted` emission. The test name literally says *"(not started)"*. **Correct value: `notStarted`.**

Only **~line 106/107** (a real `pause()` following an active `resume()`) is genuinely `paused`.

Because this is a characterization/golden-master test asserting *exact* engine output, following the plan's explicit line list would write `lifecycle: BreathLifecycle.paused` at two sites where the engine emits `notStarted`, producing **two failing assertions** in Task 5 — the very task that performs the schema bump.

Note the internal contradiction: the plan's prose states the correct *principle* ("Confirm each `pause` site is post-`resume()` before choosing `paused`"), but its explicit enumeration violates that principle. The test provides a safety net (it will fail loudly), but the plan's "answer key" is wrong and should be corrected before implementation.

**Fix:** In Trap 1 and Task 5, map the four `status: pause` sites as:
- ~L73 (initial smoke) → `notStarted` ✓ (already correct)
- ~L106/107 (pause after resume) → `paused` ✓
- ~L173 (post-restartEngine fresh initial) → **`notStarted`** (plan says `paused`)
- ~L214 (case A, never resumed) → **`notStarted`** (plan says `paused`)

## Minor Notes (non-blocking)

- **Task 2 mislabels a call site.** It refers to the first `BreathAnimationCoordinator` read as being on "the `_handleFirstReady`/initial path," but the `setActive(state.status == breath)` call is actually in `_syncInitialState` (line 46); `_handleFirstReady` only morphs shape. The count ("all four `state.status == breath` reads") is correct — lines 46, 85, 101, 127 — so the migration target set is right; only the label is imprecise.

- **State-channel `_state()` helper.** The plan's instruction to drop the `switch` and take `lifecycle` + `phase` directly is correct, and carrying each call site's `phase:` verbatim (never forcing `phase: rest`) is verified against the deliberate `status: rest, phase: exhale` case at line 963 / assertion `'exhale'` at line 967. Good.

## Positive Notes

- Exceptionally rigorous per-site trap analysis — the equality-test full-constructor trap (deleting `status: a.status` would silently leave `b.lifecycle == notStarted` and break both tests) is a genuinely subtle failure mode the plan caught and handled correctly.
- Correct sequencing: enum/field survive through Task 5 so every migrated assertion compiles before the Task 6 deletion. Three-commit grouping is clean and each commit is independently buildable.
- Correctly identifies that the state-channel test observes `phase` independently, so only the `status → lifecycle` substitution is needed there.
- The "behavior unchanged — representation only" claim holds: every mapping I traced is semantically equivalent to the old `status` derivation.

## Verdict

The plan is structurally sound and ~95% precise, but contains one concrete factual error (Critical Issue #1) that would mislead the implementer into writing two failing golden-master assertions. Fix the two `notStarted` vs `paused` mappings in Trap 1 / Task 5 before implementing.
