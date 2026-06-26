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

## Verify

- App compiles with no reference to `BreathSessionStatus`; full breath suite green against the new schema; manual smoke of a full session (audio phases, pause, complete, restart) unchanged.
