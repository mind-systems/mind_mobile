# Plan: Make session start a first-class labeled emit (`ResetReason.start`)

## Context
Give the breathing state machine an explicit "this emit is the session origin" signal by adding `ResetReason.start`, emitted only on the first activation, so animation coordinators initialize at origin instead of each consumer reinventing implicit start detection.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Label and emit the origin signal

- [x] **Task 1: Add `start` to the `ResetReason` enum**
  Files: `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart`
  Change `enum ResetReason { newCycle, rest, exerciseChange }` (line 7) to `enum ResetReason { start, newCycle, rest, exerciseChange }`. This enum is shared by both `BreathSessionStateMachineState.resetReason` and `BreathSessionState.resetReason`, so no second definition is touched.
  Guards: `resetReason` is already excluded from `equalsIgnoringTickFields` (lines 95–110) and consumed only via the raw stream — a new enum value does not perturb Riverpod consumers, so do NOT add it to the equality method. Do not alter the `copyWith` `??` semantics (the full-constructor clear path must keep working).

- [x] **Task 2: Emit `ResetReason.start` on the first activation only** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionStateMachine.dart`
  Add a `bool _hasStarted = false;` field alongside the other internal counters (near line 80). In `resume()` (line 182): keep the existing full-constructor emit (copyWith cannot clear `resetReason` to null), but compute the reason as `final reason = _hasStarted ? null : ResetReason.start;`, pass it as `resetReason: reason`, and set `_hasStarted = true;` after the emit (or guard it: set the flag only on the first pass). Subsequent resumes therefore keep `resetReason: null`, preserving the resume-vs-start distinction. The emit already carries `currentIntervalMs: _state.currentIntervalMs`, which is the nominal cadence seeded at init by milestone 57 (note 122) — no cadence change needed here.
  Do NOT add any flag-reset plumbing: restart goes through `_setupEngine()` in `BreathSessionViewModel`, which constructs a brand-new `BreathSessionStateMachine`, so `_hasStarted` is `false` again automatically and a restarted session re-fires `start`.
  Leave `pause()`, `complete()`, `_startRest()`, `_startNewCycle()` untouched — they keep their existing `resetReason` values (and the `newCycle → null` clear semantics the animation coordinators rely on must be preserved).

### Phase 2: Consume the origin signal in animation coordinators

- [x] **Task 3: Handle `ResetReason.start` as explicit origin setup in `BreathAnimationCoordinator`** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/Animation/BreathAnimationCoordinator.dart`
  The `start` emit now satisfies `state.resetReason != null` in `_onStateChanged` (line 85), so it already routes into `_handleReset` and returns early — this is the desired origin setup (shape morph + `motionEngine.resetPosition(0.0)` + phase-info + activity from the seeded cadence, instead of waiting for the first tick). In `_handleReset`'s shape selector (lines 54–58), make `start` explicit: the existing ternary picks `nextExerciseShape` only for `exerciseChange`/`rest`, so `start` already falls through to `state.currentExerciseShape`; add `ResetReason.start` to the comment/condition explicitly so the origin case reads `currentExerciseShape` by intent, not by accident. Keep `_handleFirstReady` (line 47) behavior intact — on the first ready emit it still does the immediate morph before `_handleReset` runs.

- [x] **Task 4: Handle `ResetReason.start` as explicit origin setup in `OrbAnimationCoordinator`** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/Animation/OrbAnimationCoordinator.dart`
  Same routing: `start` now enters `_handleReset` via the `resetReason != null` branch (line 96). Confirm the shape selector (lines 52–58) maps `start` to `currentExerciseShape` (it already does, since `start` is neither `exerciseChange` nor `rest`) and make it explicit per the spec. For `start`, the `rest` snap branch (line 60) is skipped and the coordinator animates from the enriched fields (`currentPhaseTotalDuration`, `remainingTicks`, `phase`) — this is the intended origin animation. No `reset()` change is needed.

### Phase 3: Optional channel realignment (guarded)

- [x] **Task 5 (optional): Key `BreathModuleStateChannel` start vs unpause off `resetReason == start`** (depends on Task 2)
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  This is explicitly optional and guarded. The channel currently distinguishes first-start from resume via `!_started` (line 77), and `_started` ALSO gates instruction sending (`_handleInstruction`, line 111). Only swap the start/unpause discriminator to `state.resetReason == ResetReason.start` if the change is clean and does not disturb the `_started` instruction gating; otherwise leave this file untouched — the milestone's value is delivered by Tasks 1–4. If left untouched, note that decision in the implementation summary rather than forcing a risky change. (Requires importing `ResetReason` into the `breath_module` show-list at line 8 if implemented.)

## Commit Plan
- **Commit 1** (after tasks 1–2): "Add ResetReason.start and emit it on first activation"
- **Commit 2** (after tasks 3–4): "Initialize breath animations at origin from ResetReason.start"
- **Commit 3** (after task 5, only if implemented): "Align breath module state channel start signal to ResetReason.start"
