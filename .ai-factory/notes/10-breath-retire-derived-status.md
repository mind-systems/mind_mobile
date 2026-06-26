# Retire the derived `status` from BreathSessionState (T8)

**Date:** 2026-06-24
**Source:** conversation context (breath lifecycle FSM refactor planning)

## Key Findings

- `enum BreathSessionStatus { pause, breath, rest, complete }` (`BreathSessionState.dart:5`) is a Cartesian smear of (lifecycle × phase-kind): `pause` = not-started | paused, `breath`/`rest` = running × phase-kind, `complete` = completed. Once `lifecycle` ([[05-breath-derive-lifecycle-islive]] / [[09-breath-extract-owned-lifecycle-fsm]]) + `phase` fully cover it and every consumer reads them, `status` is dead representation to delete — the final "version the output schema" step.
- Consumers that read `status` today and must be migrated **first**: `BreathSoundCoordinator._onStateChanged` switch (`Audio/BreathSoundCoordinator.dart:145-195`) + `_onTick` `allowTick` (`:197-206`); `BreathModuleStateChannel` ([[08-breath-channel-explicit-lifecycle]] migrates it); the animation coordinators' `shouldBeActive`; `BreathSessionScreen`'s control button; `equalsIgnoringTickFields` (`:95`).

## Details

Replace each `status` read with `lifecycle` + `phase`:
- `allowTick`'s `status == breath && phase == rest` → `lifecycle == running && phase == rest`; the `pause`/`rest` branches key off `lifecycle == paused`/`notStarted` + `phase == rest`.
- the audio `_onStateChanged` switch keys off `lifecycle` (paused/notStarted → fadeOut, running → crossfade by phase, completed → fadeOut).

Remove `status` from `BreathSessionState` + `BreathSessionStateMachineState` + all full-constructor sites + `copyWith` + `equalsIgnoringTickFields`. Migrate the golden master [[04-breath-activity-characterization-golden-master]] and `breath_module_state_channel_test.dart` assertions from `status` to `lifecycle`/`phase` — the deliberate output-schema version bump.

## Guards

- **LAST task** — only after [[06-breath-audio-islive]] / [[08-breath-channel-explicit-lifecycle]] and all in-package consumers read `lifecycle`/`phase`.
- This is the **one** task that intentionally changes the output schema (and thus edits golden-master assertions); every prior task preserved it. Behavior unchanged, representation only.

## Equivalence map

| Old `status` | Replacement |
|---|---|
| `pause` | `lifecycle == notStarted` **or** `lifecycle == paused` — NOT uniform, see per-site traps below |
| `breath` | `lifecycle == running && phase != BreathPhase.rest` |
| `rest` | `lifecycle == running && phase == BreathPhase.rest` |
| `complete` | `lifecycle == completed` |

`BreathLifecycleMachine` exposes `current`, `isRunning`, `isNotStarted`. `paused`/`completed` have no getter — compare via `current == BreathLifecycle.paused` / `== BreathLifecycle.completed` directly.

## Per-site traps in test migration (Task 5)

**Do not apply the equivalence map mechanically.** Audit each call site individually. Three confirmed traps where the uniform mapping breaks:

### Trap 1 — Golden master: `pause` is not uniformly `paused`
File: `test/BreathModule/Support/breath_activity_boundary_characterization_test.dart`

`harness.states.first` (the initial `_setupEngine` emission, before any `resume()`) must assert `lifecycle: BreathLifecycle.notStarted` — the engine starts `BreathLifecycleMachine` at `notStarted`. Every pause emission that follows an active `resume()` (lines ~106, ~172, ~214) asserts `lifecycle: BreathLifecycle.paused`. Confirm each `pause` site is post-`resume()` before choosing `paused`.

### Trap 2 — State-channel: never force `phase: BreathPhase.rest` for `rest`-status sites
File: `test/BreathModule/breath_module_state_channel_test.dart`

The helper takes `phase` as an **independent** parameter. Replacing `status: rest` → `lifecycle: running, phase: BreathPhase.rest` is wrong. The correct rule: **replace `status: X` with `lifecycle: <map(X)>` and carry every `phase:` argument verbatim — never force `phase: rest`.**

Concretely: line ~963 is a deliberate "rest status carrying `phase: exhale`" case — the assertion at ~967 checks for `'exhale'`. If you override `phase` to `rest`, the test fails. Rest-status sites with no explicit `phase:` default to `inhale` and assert only lifecycle counts — neutral, but carry phase untouched anyway.

Also: the helper's doc comment at lines ~97–110 explains how `lifecycle` was *derived from `status`* via a `switch` — this is stale after the rewrite and must be removed.

### Trap 3 — Equality test: `status: a.status` → `lifecycle: a.lifecycle`, not deleted
File: `test/BreathModule/Presentation/BreathSession/breath_session_state_equality_test.dart`

Two full-constructor sites copy every field from `a`:
- Lines ~72–90: "only resetReason differs" test — `status: a.status` at ~L74
- Lines ~98–116: "all three differ together" test — `status: a.status` at ~L100

After the base `_state()` helper is changed to `lifecycle: BreathLifecycle.running`, `a.lifecycle == running`. If `status: a.status` is simply deleted, `b.lifecycle` falls back to the constructor default `notStarted` → `equalsIgnoringTickFields` returns **false** → both tests fail.

**Correct migration: replace `status: a.status` with `lifecycle: a.lifecycle`** at both sites so the copied state preserves `a`'s lifecycle.

The base `_state()` helper must set `lifecycle: BreathLifecycle.running`. The "only lifecycle differs" test becomes `copyWith(lifecycle: BreathLifecycle.paused)` — observable because the base is `running`.

## Verify

- App compiles with no reference to `BreathSessionStatus`; full breath suite green against the new schema; manual smoke of a full session (audio phases, pause, complete, restart) unchanged.
