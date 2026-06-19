# Make session start a first-class labeled emit (`ResetReason.start`)

**Date:** 2026-06-19
**Source:** conversation context

## Key Findings

- The state machine has **no explicit "this emit is the session origin" signal**. `ResetReason { newCycle, rest, exerciseChange }` (`BreathSessionState.dart:7`) has no `start`, and `resume()` emits the first active state with `resetReason: null` (`BreathSessionStateMachine.dart:193`) — indistinguishable from any other null-reason tick emit.
- Because start is unlabeled, every consumer **reinvents start detection**: `BreathModuleStateChannel` via `!_started`; `BreathAnimationCoordinator`/`OrbAnimationCoordinator` via `_initialized` + the `resetReason == null` normal branch. This implicit, per-consumer detection is the recurring root of start-timing bugs (animation not driving until the first tick; first-instruction lag) — the same class of bug hit twice.
- `start` is semantically distinct from `resume`: a cold start has no prior cadence/position; a resume continues an existing phase. Today `resume()` serves both and labels neither.
- Fix: add `ResetReason.start`, emit it on the first activation only, and have consumers key the origin off that explicit signal instead of inferring it. This is the "start gets its own flow" expressed minimally — a labeled emit, not a separate method (`resume()` already emits at the tap; only the *label* is missing).

## Details

### Current state
- `enum ResetReason { newCycle, rest, exerciseChange }` — `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart:7` (shared by both `BreathSessionStateMachineState.resetReason` and `BreathSessionState.resetReason`).
- `BreathSessionStateMachine.resume()` (line 182) flips pause→rest/breath using the full constructor with `resetReason: null` (line 193). It is the entry for **both** cold start and resume-after-pause and does not distinguish them.
- `BreathSessionViewModel` already maps `engineState.resetReason` → `BreathSessionState.resetReason` (lines 151, 188) — a new enum value propagates automatically.
- `BreathAnimationCoordinator._onStateChanged` (line 78): `if (!_initialized) _handleFirstReady(...)`; `if (state.resetReason != null) { _handleReset(...); return; }`; else normal-activity branch. `_handleReset` (line 54) chooses shape from `exerciseChange`/`rest` and resets motion/phase-info. `OrbAnimationCoordinator` mirrors this.

### The change
1. Add `start` to `ResetReason` in `BreathSessionState.dart:7`.
2. In `BreathSessionStateMachine`, add `bool _hasStarted = false`. In `resume()`, when activating from the initial pause with `!_hasStarted`, emit `resetReason: ResetReason.start` and set `_hasStarted = true`; subsequent resumes keep `resetReason: null` (resume stays distinct from start). The emit carries the nominal `currentIntervalMs` seeded by note 122.
3. `BreathAnimationCoordinator`/`OrbAnimationCoordinator` `_onStateChanged`: handle `resetReason == ResetReason.start` as an explicit origin setup — route into the reset path (or a dedicated `_handleStart`) so shape + motion + phase-info initialize at origin from the seeded cadence, not on the first tick. In `_handleReset`'s shape selector, add the `start` case → `currentExerciseShape`.

### Dependencies / scope
- Depends on note 122 (so the start emit carries a real nominal cadence instead of `-1`). Pairs with — but is independent of — note 121 (the offset axis takes the origin from a `Stopwatch`, not from this label).
- Optional alignment (separate, guarded): `BreathModuleStateChannel` could key `_channel.start()` vs `_channel.unpause()` off `resetReason == start` instead of `!_started`. Its `_started` flag also gates instruction sending, so do this only if the swap is clean — otherwise leave the channel's logic untouched; this milestone's value is the labeled emit + animation consuming it.

### Guards
- `resetReason` is excluded from `equalsIgnoringTickFields` and consumed only via the raw stream (`BreathSessionState.dart:82-85`) — a new enum value does not perturb Riverpod consumers.
- Preserve the `newCycle → null` clear-emit semantics the animation coordinators rely on.
- `resume()` must keep using the full constructor (copyWith cannot clear `resetReason` to null).

## Open Questions

- Should a restart (`reset()` → play again) re-fire `ResetReason.start`? `_hasStarted` would need resetting on the engine restart path — confirm where restart re-arms the machine and reset the flag there so a restarted session also gets a labeled origin.
  **Resolution:** it re-fires automatically — `restartEngine() → _setupEngine()` (`BreathSessionStateMachine.dart:131`) constructs a NEW state-machine instance, so `_hasStarted` is `false` again with no reset plumbing. Do NOT add flag-reset code.
