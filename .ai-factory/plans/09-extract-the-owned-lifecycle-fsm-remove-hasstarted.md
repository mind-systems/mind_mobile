# Plan: Extract the owned lifecycle FSM, remove `_hasStarted`

## Context
Make the breath session lifecycle a first-class owned sub-machine (`BreathLifecycleMachine`) so `lifecycle` becomes a single source of truth that `pause/resume/complete` mutate directly, instead of being derived from `(status, _hasStarted)`. Pure behavior-preserving cleanup — golden master + isLive suite stay green with no assertion changes.

## Settings
- Testing: no (reuse existing suites — behavior-preserving, no new tests)
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Owned lifecycle sub-machine

- [x] **Task 1: Add `BreathLifecycleMachine` sub-machine**
  Files: `packages/breath_module/lib/src/BreathSession/BreathLifecycleMachine.dart`
  Create a small pure-Dart class that owns a single `BreathLifecycle` value (import the existing enum from `Models/BreathSessionState.dart`) and the only legal transitions of `notStarted → running ⇄ paused → completed`. Public surface:
  - `BreathLifecycle get current` — the owned value, starts at `BreathLifecycle.notStarted`.
  - `bool get isRunning` — `current == BreathLifecycle.running` (used by the tick gate).
  - `bool get isNotStarted` — `current == BreathLifecycle.notStarted` (used by `resume()` to decide first-resume `ResetReason.start`).
  - `void run()` — `notStarted → running` and `paused → running`; no-op when already `completed` (guards against re-running a finished session).
  - `void pause()` — `running → paused` only; no-op from `notStarted`/`paused`/`completed` (preserves the existing "pre-resume pause stays notStarted" behavior).
  - `void complete()` — transitions to `completed` from any state.
  Do NOT add a `completed → notStarted` transition — restart stays a rebuild (Task 2 keeps `restartEngine` re-instantiating the engine). No Flutter/Riverpod imports — this is domain-layer pure Dart.

### Phase 2: Wire the engine to the owned machine

- [x] **Task 2: Source `lifecycle` from the machine and remove `_hasStarted`** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionStateMachine.dart`, `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart`
  In `BreathSessionStateMachine`:
  - Add `final BreathLifecycleMachine _lifecycle = BreathLifecycleMachine();` field. Remove the `bool _hasStarted = false;` field (`:89`).
  - `_emit` (`:507`): stamp `lifecycle: _lifecycle.current` instead of `_lifecycleFor(newState.status)`. Delete the now-unused `_lifecycleFor` helper (`:494`) and its doc comment. `status` stays emitted explicitly per-emit exactly as today (status derivation is deferred to note `10-breath-retire-derived-status`).
  - `resume()` (`:189`): keep the `if (_state.status != BreathSessionStatus.pause) return;` guard. Replace the `_hasStarted` read with `final reason = _lifecycle.isNotStarted ? ResetReason.start : null;`, then call `_lifecycle.run()`. Remove the trailing `_hasStarted = true;` (`:211`). The emitted `status` (`wasResting ? rest : breath`) is unchanged.
  - `pause()` (`:170`): call `_lifecycle.pause()` before emitting. Keep the existing early-return on `status == complete` and keep emitting the full pause state (clears `resetReason`) so the golden master's recorded emissions are unchanged.
  - `complete()` (`:214`): call `_lifecycle.complete()` before emitting; everything else (the `remainingTicks: 0` emit, `_tickSubscription?.cancel()`) unchanged.
  - `_onTick` (`:241`): replace the `status == pause || status == complete` early-return with `if (!_lifecycle.isRunning) return;`. Keep the `switch (_state.status)` branch selection (breath vs rest) below it — that selects the progression path, not the gate. Progression math (`_onBreathTick`/`_onRestTick`/`_advanceExercise`/`_startRest`/`_startNewCycle`) is untouched.
  In `Models/BreathSessionState.dart`: update the `BreathLifecycle` enum doc comment (`:10`) and the `lifecycle` field comment (`:51`) to describe lifecycle as owned/sourced by the sub-machine rather than "derived from `(status, _hasStarted)`" — accuracy only, no logic change.
  Leave `BreathSessionViewModel` untouched: it already reads `engineState.lifecycle` in `_setupEngine`/`_onEngineState`, and `restartEngine` → `_setupEngine` re-instantiates the engine (and thus a fresh `BreathLifecycleMachine` at `notStarted`).

## Acceptance
- `test/BreathModule/Presentation/BreathSession/breath_lifecycle_islive_test.dart` (isLive suite), `breath_session_state_machine_test.dart`, and `test/BreathModule/Support/breath_activity_boundary_characterization_test.dart` (golden master) all pass with **no assertion edits**.
- No remaining references to `_hasStarted` or `_lifecycleFor` in the codebase.
