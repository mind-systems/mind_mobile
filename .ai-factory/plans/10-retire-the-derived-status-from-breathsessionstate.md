# Plan: Retire the derived `status` from `BreathSessionState`

## Context
Delete the smeared `BreathSessionStatus` enum (a Cartesian smear of lifecycle × phase-kind) now that `lifecycle` + `phase` fully cover it. Migrate every remaining in-package consumer to read `lifecycle`/`phase`, remove `status` from both state structs, then bump the output schema in the golden-master + state-channel tests. Behavior unchanged — representation only.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Equivalence map (reference for all tasks)

`status` derives from `lifecycle` (`BreathLifecycle`) + `phase` (`BreathPhase`) as follows:

| Old `status` | Equivalent `lifecycle` + `phase` |
|---|---|
| `pause` | `lifecycle == notStarted` **or** `lifecycle == paused` (i.e. `lifecycle != running && lifecycle != completed`) |
| `breath` | `lifecycle == running && phase != BreathPhase.rest` |
| `rest` | `lifecycle == running && phase == BreathPhase.rest` |
| `complete` | `lifecycle == completed` |

Notes:
- Initial states emit `lifecycle == notStarted` (the engine starts `BreathLifecycleMachine` at `notStarted` and `_emit` stamps `_lifecycle.current`).
- `BreathLifecycleMachine` exposes `current`, `isRunning`, `isNotStarted`. Compare `current == BreathLifecycle.paused` / `== BreathLifecycle.completed` directly where no getter exists.

## Per-site traps (do NOT apply the map mechanically — audit each call site)

### Trap 1 — Golden master: `pause` is mostly `notStarted`, only one site is `paused`
File: `test/BreathModule/Support/breath_activity_boundary_characterization_test.dart`
This is a characterization test asserting **exact** engine output, so each `status: pause` site needs its true lifecycle, NOT a uniform value. Only an emission produced by a `pause()` call *on a still-live engine that was actually resumed* is `paused`; a fresh/never-resumed engine emits `notStarted`. Per-site answer key (4 sites):
- **~L73 (initial smoke, before any `resume()`)** → `notStarted`. The engine starts `BreathLifecycleMachine` at `notStarted`; the initial state is set via `_initial*State()` (no `_emit`).
- **~L106/107 (a real `pause()` after an active `resume()`)** → `paused`. The only genuinely-paused site.
- **~L173 (post-`restartEngine()`)** → `notStarted`, NOT `paused`. `restartEngine()` → `_setupEngine()` constructs a **fresh** `BreathSessionStateMachine` whose lifecycle starts at `notStarted`; the earlier `resume()` (~L142) applied to the discarded engine and is irrelevant.
- **~L214 (case A — "ticks in initial pause (not started)")** → `notStarted`, NOT `paused`. The default harness is never resumed; all ticks early-return in `_onTick` (`!_lifecycle.isRunning`), so `states.last` is still the initial `notStarted` emission.
Rule of thumb: a `pause` site is `paused` only if a live `resume()` precedes it with no intervening `restartEngine()`/fresh construction.

### Trap 2 — State-channel: never force `phase: BreathPhase.rest` for `rest`-status sites
File: `test/BreathModule/breath_module_state_channel_test.dart`
Rule: **replace `status: X` with `lifecycle: <map(X)>` and carry every `phase:` argument verbatim — never force `phase: rest`.**
Line ~963 is a deliberate "rest status carrying `phase: exhale`" case; assertion at ~967 checks `'exhale'`. Forcing `phase: rest` breaks it. Rest-status sites with no explicit `phase:` default to `inhale` — leave them untouched.
Also remove/rewrite the helper's doc comment at lines ~97–110 that explains how `lifecycle` is derived from `status` via a `switch` — stale after rewrite.

### Trap 3 — Equality test: `status: a.status` → `lifecycle: a.lifecycle`, not deleted
File: `test/BreathModule/Presentation/BreathSession/breath_session_state_equality_test.dart`
Two full-constructor sites copy every field from `a`:
- Lines ~72–90: "only resetReason differs" test — `status: a.status` at ~L74
- Lines ~98–116: "all three differ together" test — `status: a.status` at ~L100
After `_state()` sets `lifecycle: BreathLifecycle.running`, `a.lifecycle == running`. Simply deleting `status: a.status` leaves `b.lifecycle` at the default `notStarted` → `equalsIgnoringTickFields` returns false → both tests fail.
**Correct migration: replace `status: a.status` with `lifecycle: a.lifecycle`** at both sites.

## Tasks

### Phase 1: Migrate in-package consumers off `status` (field still present)

- [x] **Task 1: Migrate `BreathSoundCoordinator` to `lifecycle`/`phase`**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Replace the `BreathSessionStatus? _currentStatus` tracking field with `BreathLifecycle? _currentLifecycle`.
  - `reset()` — set `_currentLifecycle = null` instead of `_currentStatus = null`.
  - `toggleMute()` — the un-mute restore condition `_currentStatus == breath` becomes `_currentLifecycle == BreathLifecycle.running && _currentPhase != null && _phaseAssets.containsKey(_currentPhase)` (running with a real phase asset; rest has no asset).
  - `_onStateChanged()` — replace the "3. Status changes" block (currently keyed on `state.status != _currentStatus`) with a lifecycle-keyed block (`state.lifecycle != _currentLifecycle`):
    - `notStarted` / `paused` → `_looper.fadeOut(200ms)`.
    - `completed` → `_looper.fadeOut(500ms)`.
    - `running` → behave like the old `breath` branch: track phase, and if the phase changed and has an asset, `crossfadeTo` with `_computeFadeDuration`; else `fadeIn(200ms)`. When `phase == rest` (no asset) fall through to `fadeOut(500ms)`.
    The existing "4. Phase changes" block already keys off `state.phase` — keep it (it handles same-lifecycle phase transitions, including rest → no-asset fadeOut).
  - `_onTick()` `allowTick` — replace with the equivalence-map expansion:
    `allowTick = _currentLifecycle == BreathLifecycle.notStarted || _currentLifecycle == BreathLifecycle.paused || (_currentLifecycle == BreathLifecycle.running && _currentPhase == BreathPhase.rest)`.
    (`completed` is excluded, matching the old exclusion of `complete`.)

- [x] **Task 2: Migrate animation coordinators to `lifecycle`/`phase`**
  Files: `packages/breath_module/lib/src/BreathSession/Animation/BreathAnimationCoordinator.dart`, `packages/breath_module/lib/src/BreathSession/Animation/OrbAnimationCoordinator.dart`
  Define "actively breathing" as `state.lifecycle == BreathLifecycle.running && state.phase != BreathPhase.rest` (the old `status == breath`).
  - `BreathAnimationCoordinator` — replace all four `state.status == BreathSessionStatus.breath` reads (lines 46, 85, 101, 127: `setActive(...)` in `_syncInitialState` at L46, the `setActive(...)` after phase-index update at L85, the `shouldBeActive` computation at L101, and the `if (state.status == breath && state.totalPhases > 0)` guard at L127) with the "actively breathing" expression.
  - `OrbAnimationCoordinator` — replace `state.status != BreathSessionStatus.breath` (freeze-orb guard) with `!(state.lifecycle == BreathLifecycle.running && state.phase != BreathPhase.rest)`.

- [x] **Task 3: Migrate the screen control button + timeline widget to `lifecycle`** (depends on nothing)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`, `packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart`
  - `BreathSessionScreen` — change both `breathViewModelProvider.select` tuples that read `s.status` to read `s.lifecycle`. In `_buildControlButton`, change the param type to `BreathLifecycle lifecycle`; `status == complete` → `lifecycle == BreathLifecycle.completed`; `isPaused = status == pause` → `isPaused = lifecycle != BreathLifecycle.running` (the not-running, not-complete case already falls through after the complete check). Pass `lifecycle:` to `BreathTimelineWidget` instead of `status:`.
  - `BreathTimelineWidget` — change the `status` field to `BreathLifecycle? lifecycle`. `isComplete = status == complete` → `lifecycle == BreathLifecycle.completed`. For `isPausedOrComplete`, **do not** use `lifecycle != running` — with a null `lifecycle` that inverts the old null→false default. Preserve it explicitly: `isPausedOrComplete = lifecycle == BreathLifecycle.paused || lifecycle == BreathLifecycle.notStarted || lifecycle == BreathLifecycle.completed` (null stays false).

### Phase 2: Migrate the state machine's internal logic off `status`

- [x] **Task 4: Drive `BreathSessionStateMachine` control flow from `lifecycle`/`phase`** (depends on Task 1-3 conceptually; independent files)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionStateMachine.dart`
  Replace the internal `_state.status` reads (the field stays populated for now; only the reads move):
  - `pause()` guard `if (_state.status == complete) return;` → `if (_lifecycle.current == BreathLifecycle.completed) return;`.
  - `resume()` guard `if (_state.status != pause) return;` → proceed only from not-started/paused: `if (_lifecycle.isRunning || _lifecycle.current == BreathLifecycle.completed) return;`. The `wasResting` computation already uses `_state.phase == BreathPhase.rest` — keep it; it still selects the resumed `status`/phase correctly.
  - `_onTick()` switch on `_state.status` (breath vs rest) → dispatch on phase: after the `if (!_lifecycle.isRunning) return;` gate, call `_onRestTick` when `_state.phase == BreathPhase.rest`, else `_onBreathTick`. (When running, `phase == rest` ⟺ old `status == rest`; otherwise breath.)

### Phase 3: Remove the field + enum and version-bump the tests

- [x] **Task 5: Migrate all breath tests off the `status` field and `BreathSessionStatus` enum** (depends on Task 4)
  Files: `test/BreathModule/breath_module_state_channel_test.dart`, `test/BreathModule/Support/breath_activity_boundary_characterization_test.dart`, `test/BreathModule/Support/breath_activity_harness_test.dart`, `test/BreathModule/Presentation/BreathSession/breath_session_state_machine_test.dart`, `test/BreathModule/Presentation/BreathSession/breath_session_enriched_state_test.dart`, `test/BreathModule/Presentation/BreathSession/breath_session_state_equality_test.dart`, `test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart`
  This is the deliberate output-schema version bump. The enum and field still exist during this task, so each migrated assertion compiles before removal in Task 6.
  - `breath_module_state_channel_test.dart` — rewrite the `_state({...})` helper to take `BreathLifecycle lifecycle` + `BreathPhase phase` directly (drop the `status` param and the `switch`). `phase` is already an **independent** helper param here, and the channel observes it directly (it stamps `state.phase.name` into every marker/sample and tracks `_previousPhase`). So the only rewrite per call site is: **replace `status: BreathSessionStatus.X` with `lifecycle: <map(X)>` and carry each call site's existing `phase:` argument verbatim** — `breath`/`rest` → `lifecycle: running`; `pause` → `lifecycle: paused`; `complete` → `lifecycle: completed`. **Never force `phase: BreathPhase.rest`** — that would break the deliberate "rest status carrying a non-rest phase" case at ~line 963 (`status: rest, phase: BreathPhase.exhale`), whose assertion at ~line 967 checks for `'exhale'`. The rest-status sites with no explicit `phase:` (lines ~303, 334, 350, 368, 407, 471, 763) keep their `inhale` default and assert only lifecycle-transition counts, so leaving phase untouched is correct everywhere. "Preserve the exact `(lifecycle, phase)` the channel observes" is the governing rule for this file. Also remove/rewrite the helper's doc comment (~lines 97–110) that explains how `lifecycle` is *derived from `status`* via the `switch` — once `lifecycle` is taken directly that rationale is stale.
  - `breath_activity_boundary_characterization_test.dart` (golden master) — change the `expectState(...)` helper's `status` param to `lifecycle` (+ keep `phase`), and rewrite each `expectState(... status: BreathSessionStatus.X ...)` to assert `lifecycle`/`phase`. `complete` → `completed`; `breath`/`rest` → `running` (± `phase` as already asserted). **`pause` does NOT map uniformly — three of the four `pause` sites are `notStarted`, only one is `paused`.** Use the Trap 1 per-site answer key exactly: ~L73 (initial smoke) → `notStarted`; ~L106/107 (real `pause()` after a live `resume()`) → `paused`; ~L173 (post-`restartEngine()`, fresh engine) → `notStarted`; ~L214 (case A, never resumed) → `notStarted`. Do not write `paused` at ~L173 or ~L214 — the engine emits `notStarted` there and the assertion would fail.
  - `breath_activity_harness_test.dart` — `s.status == breath` → `s.lifecycle == running && s.phase != BreathPhase.rest`; `states.last.status == complete` → `states.last.lifecycle == completed`.
  - `breath_session_state_machine_test.dart` — `currentState.status == complete/pause/breath` → `lifecycle == completed` / `lifecycle == paused` / `lifecycle == running && phase != rest`.
  - `breath_session_enriched_state_test.dart` — `currentState.status == rest` → `lifecycle == running && phase == rest`; `== complete` → `lifecycle == completed`; the `BreathSessionState(status: breath, ...)` construction → drop `status:` and set `lifecycle: BreathLifecycle.running` (+ phase as appropriate).
  - `breath_session_state_equality_test.dart` — the base `_state()` helper currently sets `status: breath` and leaves `lifecycle` at its `notStarted` default; replace that with an explicit `lifecycle: BreathLifecycle.running` (matches the old `breath`). The "only status differs" test becomes an `equalsIgnoringTickFields` check on a differing `lifecycle` — `copyWith(lifecycle: BreathLifecycle.paused)`; the `running` base makes the difference observable (a `paused`-or-`notStarted` base would make the differ-test a no-op). **Also rewrite the two full-constructor sites** that copy fields from `a`: lines ~72–90 ("only resetReason differs") and ~98–116 ("all three differ together") — replace `status: a.status` with `lifecycle: a.lifecycle` at both. Simply deleting `status: a.status` leaves `b.lifecycle` at the `notStarted` default, making `equalsIgnoringTickFields` return false and breaking both tests.
  - `breath_view_model_publication_test.dart` — `published.last.status == complete` → `published.last.lifecycle == completed`.
  - In every file above, remove `BreathSessionStatus` from the `import ... show ...` clause.

- [x] **Task 6: Delete the `status` field and the `BreathSessionStatus` enum** (depends on Task 5)
  Files: `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart`, `packages/breath_module/lib/src/BreathSession/BreathSessionStateMachine.dart`, `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
  - `BreathSessionState` — remove the `status` field, its constructor param, the `status:` line in `BreathSessionState.initial()`, the `status` param + line in `copyWith`, and the `status == other.status` clause in `equalsIgnoringTickFields`.
  - `BreathSessionStateMachineState` — remove the `status` field, constructor param, and `copyWith` param/line.
  - `BreathSessionStateMachine` — remove `status:` from every full-constructor emit site (`_initialRestState`, `_initialBreathState`, `pause`, `resume`, `complete`, `_onBreathTick`, `_onRestTick`, `_startRest`, `_startNewCycle`).
  - `BreathSessionViewModel` — remove `status: initialEngineState.status` and `status: engineState.status` from the two `BreathSessionState(...)` construction sites.
  - Delete `enum BreathSessionStatus { pause, breath, rest, complete }` from `BreathSessionState.dart`. (It is exported transitively via `breath_module.dart`'s whole-file export — no export-list edit needed.)
  - Final check: no remaining reference to `BreathSessionStatus` or `.status` (on a breath state) anywhere in `packages/breath_module/` or `test/BreathModule/`.

## Commit Plan
- **Commit 1** (after tasks 1-3): "Migrate breath audio, animation, and screen consumers to lifecycle and phase"
- **Commit 2** (after task 4): "Drive breath session state machine control flow from lifecycle and phase"
- **Commit 3** (after tasks 5-6): "Remove derived BreathSessionStatus, version-bump breath state schema and tests"
