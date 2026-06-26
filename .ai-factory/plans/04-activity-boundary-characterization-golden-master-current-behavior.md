# Plan: Activity-boundary characterization golden master (current behavior)

## Context
Pin the breath activity's *current* observable behavior at the boundary (the emitted `BreathSessionState` sequence) as an executable golden master, so the later lifecycle-FSM surgery (notes 09/10) cannot silently break the untested `_hasStarted` discriminator, restart reset, or tick-ignored invariants. Test-only — no production change.

## Settings
- Testing: yes (this milestone *is* the test addition)
- Logging: no
- Docs: no

## Key facts (from code recon)

- The harness `BreathActivityHarness` (`test/BreathModule/Support/BreathActivityHarness.dart`) and all fakes (`test/BreathModule/Fakes/BreathActivityFakes.dart`) already exist and expose: `init()`, `tick([ms])`, `resume()`, `pause()`, `complete()`, `restartEngine()`, and the recorded `states` (`List<BreathSessionState>` from `vm.stream`), `channel` and `instructionStream` call-logs.
- `harness.states` records **every** `set state` call — `vm.stream` (`BreathSessionViewModel.dart:108-115`) is NOT deduped (only Riverpod `super.state` is). An ignored tick produces **no** emission, so `states.length` is a reliable "did anything happen" probe.
- Default DTO = `makeSession([makeExercise()])` → one exercise, `inhale=2 + exhale=2` (`cycleDuration=4`, `repeatCount=1`). Initial `_setupEngine` emission: `status=pause`, `phase=inhale`, `exerciseIndex=0`, `remainingTicks=2`, `resetReason=null` (`BreathSessionStateMachine._initialBreathState:138`).
- `_hasStarted` discriminator (`BreathSessionStateMachine.dart:189/205`): first `resume()` emits `resetReason=ResetReason.start`; every later `resume()` emits `resetReason=null`. `pause()` clears `resetReason` to null (`:164`).
- `restartEngine()` (`BreathSessionViewModel.dart:282`) → `_onModuleReset` + `_setupEngine` (`:139`) builds a **brand-new** state machine: counters zeroed (`exerciseIndex=0`), `_hasStarted=false` again, fresh initial `pause`, `resetReason=null`.
- `_onTick` (`BreathSessionStateMachine.dart:235-238`) returns early when `status == pause || status == complete` → no emission, no progression.
- Tests must `await pumpEventQueue()` after each input — `vm.stream` is a broadcast controller delivering asynchronously (see the existing smoke test, `breath_activity_harness_test.dart`).

## Guards (do not violate)

- Assert ONLY on the **current** schema fields: `status`, `phase`, `exerciseIndex`, `resetReason`, `remainingTicks`. Do NOT assert on `lifecycle`/`isLive` (added later by note 05; these tests are migrated by note 10).
- Suite must be **green NOW** against the unmodified production code. No production file may change.
- Do NOT rewrite or touch the existing `breath_session_state_machine_test.dart` or `breath_module_state_channel_test.dart` — they are the cheaper inner net and part of the preserved contract.

## Tasks

### Phase 1: Characterization suite

- [x] **Task 1: Scaffold the golden-master test file + assertion helper**
  Files: `test/BreathModule/Support/breath_activity_boundary_characterization_test.dart`
  Create the suite reusing `BreathActivityHarness` and the existing fakes. Pattern after `breath_activity_harness_test.dart`: `setUp` builds the harness and `await harness.init()`; `tearDown` calls `harness.dispose()`. Import `BreathSessionState`, `BreathSessionStatus`, `BreathPhase`, `ResetReason` from `package:breath_module/breath_module.dart`. Add a small local helper `expectState(BreathSessionState s, {BreathSessionStatus? status, BreathPhase? phase, int? exerciseIndex, Object? resetReason, int? remainingTicks})` that asserts only the provided fields (so each case reads as an input→output tuple). Add a smoke assertion that `harness.states` already contains the initial `_setupEngine` emission (`status=pause`, `phase=inhale`, `exerciseIndex=0`, `remainingTicks=2`, `resetReason=null`) to anchor the starting point.

- [x] **Task 2: `_hasStarted` resume discriminator group** (depends on Task 1)
  Files: `test/BreathModule/Support/breath_activity_boundary_characterization_test.dart`
  Group "resume discriminator (`_hasStarted`)". Drive `resume()` → pump → assert the new state is `status=breath`, `phase=inhale`, `resetReason=ResetReason.start` (first activation). Then `pause()` → pump → assert `status=pause`, `resetReason=null`. Then `resume()` again → pump → assert `status=breath`, `resetReason=null` (second activation, distinct observable output). This is the core untested in-engine "not-started vs paused" contract expressed as input→output.

- [x] **Task 3: restart-after-complete fresh-state group** (depends on Task 1)
  Files: `test/BreathModule/Support/breath_activity_boundary_characterization_test.dart`
  Group "restart after complete → fresh initial pause". Use a **two-exercise** session (`BreathActivityHarness(session: makeSession([makeExercise(), makeExercise()]))`) so the exerciseIndex reset is observable. `resume()`, drive 4 ticks (exhaust ex0 → advances to ex1), drive 4 more ticks (exhaust ex1 → engine calls `complete()`); pump and assert the last state is `status=complete`, `exerciseIndex=1`, `remainingTicks=0`. Then `restartEngine()` → pump → assert the fresh state is `status=pause`, `phase=inhale`, `exerciseIndex=0`, `remainingTicks=2`, `resetReason=null` (counters zeroed, `_setupEngine` rebuild). Add one extra assertion that `_hasStarted` re-armed: a `resume()` after restart again emits `resetReason=ResetReason.start`.

- [x] **Task 4: tick-ignored-in-pause and tick-ignored-in-complete group + green run** (depends on Tasks 2, 3)
  Files: `test/BreathModule/Support/breath_activity_boundary_characterization_test.dart`
  Group "ticks ignored outside running". Case A (pause / not-started): immediately after `init()` (status `pause`, not started), record `harness.states.length`, fire `tick()` ×3 with pumps, assert `states.length` is unchanged and the last state is still `status=pause`, `phase=inhale`, `exerciseIndex=0`, `remainingTicks=2` (no progression, `_onTick:237`). Case B (complete): `resume()`, `complete()`, pump, record `states.length`, fire `tick()` ×3 with pumps, assert `states.length` unchanged and last state still `status=complete`. Finally run `flutter test test/BreathModule/Support/breath_activity_boundary_characterization_test.dart` (use the full Flutter path `/usr/local/bin/flutter`) and confirm the whole suite is green against unmodified production code.
