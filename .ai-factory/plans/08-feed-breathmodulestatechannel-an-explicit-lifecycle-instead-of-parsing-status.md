# Plan: Feed `BreathModuleStateChannel` an explicit lifecycle instead of parsing status

## Context
`BreathModuleStateChannel._handleLifecycle` currently re-derives the activity lifecycle from `BreathSessionStatus` transitions to drive the server commands `start/unpause/pause/end`. This milestone switches the input discriminator to the explicit `state.lifecycle` signal (already present on `BreathSessionState`) so the backend stops interpreting `status` meanings — a pure input substitution that keeps behavior byte-identical.

## Settings
- Testing: yes (golden-master regression only — `breath_module_state_channel_test.dart` must stay green; no new behavioral suites)
- Logging: minimal (keep existing `logPrint` lines unchanged)
- Docs: no

## Background (verified during exploration)

- `BreathSessionState.lifecycle` (`enum BreathLifecycle { notStarted, running, paused, completed }`) already exists and is stamped at emit time by the state machine (`BreathSessionStateMachine._lifecycleFor` / `_emit`). Mapping the SM uses: `complete→completed`, `breath|rest→running`, `pause & _hasStarted→paused`, `pause & !_hasStarted→notStarted`.
- The channel reads `BreathSessionStatus` in two places: `_handleLifecycle` (`:75-115`) and the `isActive` gate inside `_handleInstruction` (`:119-121`). `_previousStatus` (`:19`, set in `_onState:61`, cleared in `reset():151`) is the only state tracked solely for the lifecycle discriminator.
- **Byte-equivalent status→lifecycle mapping** (confirmed against every branch + the full golden master):
  - `isActive` (`status ∈ {breath, rest}`) ≡ `lifecycle == running`
  - `wasActive` (prev `∈ {breath, rest}`) ≡ `_previousLifecycle == running`
  - `wasPaused` (prev `∈ {pause, null}`) ≡ `_previousLifecycle ∈ {notStarted, paused, null}`
  - `status == pause` (branch-2 target) ≡ `lifecycle == paused`
  - `status == complete` ≡ `lifecycle == completed`
  - The `notStarted` vs `paused` distinction is **invisible to the channel** — both fall in the "was inactive" set, and `start` vs `unpause` is decided by `_started`, not by the lifecycle value. A `completed → running` transition must remain a no-op (matches the current `wasPaused=false` short-circuit).
- **Test impact (the anticipated "feed-shape change"):** the `_state(...)` helper in the test never sets `lifecycle`, so it currently defaults to `notStarted` on every emitted state. Once the channel branches on `lifecycle`, the helper must stamp a status-derived `lifecycle` or every transition collapses to `notStarted` and the suite breaks. Defaulting `pause→paused` (plus `breath|rest→running`, `complete→completed`) is sufficient and keeps **all** existing assertions green — verified case-by-case: first-emission `pause`, `pause→pause`, `breath→pause`, `complete→pause→complete`, the loadState-filter cases, and every `reset()` case all produce identical channel call sequences.

## Tasks

### Phase 1: Switch the channel discriminator

- [x] **Task 1: Replace `_previousStatus` with `_previousLifecycle` and rewrite `_handleLifecycle` to branch on `state.lifecycle`**
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  - Update the import on `:9` to pull `BreathLifecycle` from `package:breath_module/breath_module.dart` and drop `BreathSessionStatus` (it is no longer referenced after Task 2).
  - Replace the field `BreathSessionStatus? _previousStatus;` (`:19`) with `BreathLifecycle? _previousLifecycle;`.
  - In `_onState` (`:61`), replace `_previousStatus = state.status;` with `_previousLifecycle = state.lifecycle;`.
  - In `reset()` (`:151`), replace `_previousStatus = null;` with `_previousLifecycle = null;`.
  - Rewrite `_handleLifecycle` to read `final lifecycle = state.lifecycle;`, short-circuit on `lifecycle == _previousLifecycle`, then apply the byte-equivalent mapping from Background:
    - `wasInactive` = `_previousLifecycle ∈ {notStarted, paused, null}`; `isRunning` = `lifecycle == running`; `wasRunning` = `_previousLifecycle == running`.
    - Branch 1 (`wasInactive && isRunning`): `!_started` ⇒ existing **start** block (reset+start stopwatch, capture `_originWallClock`, `_channel.start(...)`, set `_started`, null out `_previousPhase`/`_previousExerciseIndex`); else ⇒ existing **unpause** block (`_channel.unpause()`, `_emitMarker(...)`, refresh `_previousPhase`/`_previousExerciseIndex`).
    - Branch 2 (`wasRunning && lifecycle == paused`): keep the `_started && !_ended` guard ⇒ existing **pause** block (`_channel.pause()`, `_emitMarker('pause', 0, ...)`).
    - Branch 3 (`lifecycle == completed`): keep the `_started && !_ended` guard ⇒ existing **end** block (`_channel.end(...)`, set `_ended`).
  - Keep `_started`/`_ended`, the stopwatch + `_originWallClock`, all `logPrint` lines, `_emitMarker`, `_flushPending`, `dispose()→stop`, and subscription wiring exactly as-is. Only the discriminator and its tracked previous-value change.

- [x] **Task 2: Re-gate `_handleInstruction` on `lifecycle == running`** (depends on Task 1)
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  - In `_handleInstruction` (`:119-121`), replace the `isActive` computation (`state.status == breath || state.status == rest`) with `state.lifecycle == BreathLifecycle.running`.
  - Leave the rest of the method untouched — phase markers already read `state.phase` (`state.phase.name`), and `_previousPhase`/`_previousExerciseIndex`/`currentPhaseTotalDuration` handling is unchanged.

### Phase 2: Keep the golden master green

- [x] **Task 3: Stamp `lifecycle` on states emitted by the test helper** (depends on Task 2)
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  - Update the `_state({...})` helper (`:103-120`) so the constructed `BreathSessionState` carries a `lifecycle` derived from `status`: `breath|rest → running`, `complete → completed`, `pause → paused`.
  - Add the `BreathLifecycle` symbol to the `breath_module` `show` import on `:11-12`.
  - Add a short comment noting that a single faked `pause` state cannot distinguish `notStarted` from `paused`, and that the channel treats both identically in the "was inactive" check — so `pause→paused` is the correct default and the only constraint (a pause following an active state must be `paused`) is satisfied.
  - Do **not** edit individual test bodies or assertions; the helper change alone keeps the suite green.

- [x] **Task 4: Run the golden-master suite and confirm green** (depends on Task 3)
  Files: (none — verification only)
  - Run `/usr/local/bin/flutter test test/BreathModule/breath_module_state_channel_test.dart` and confirm every test passes with identical `start/unpause/pause/end/stop` and `sendSample` call sequences. If anything fails, reconcile against the byte-equivalent mapping in Background (do not change behavior).
