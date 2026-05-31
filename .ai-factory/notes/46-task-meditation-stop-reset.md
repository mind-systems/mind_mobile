# Task Spec — Make meditation Stop reset the lifecycle (re-arm the state-channel)

**Date:** 2026-05-31
**Roadmap:** ROADMAP.md Phase 26
**Provenance:** note 41 (review) + design thread

## Intent
Meditation **Stop = a full reset of the module to its initial state** — semantically identical to a breath exercise *completing* and the user pressing *restart*. Breath models this: `BreathModuleStateChannel` ends only on `complete` and re-arms `_started`/`_ended` via `reset()` (`:110`) on restart.

## Current state
The meditation copy kept the re-pressable Start/Stop toggle (`MeditationSessionViewModel.start()/stop()`; `MeditationSessionScreen` icon `play_arrow`↔`stop` — already correct, not a pause) but dropped the re-arm, leaving one-shot `_started`/`_ended` in `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`. On a 2nd Start→Stop→Start within one screen mount: the 2nd `active` skips `_channel.start()` (`!_started` false), the idle branch no-ops (`_ended` true), and dispose skips `stop()` — so 2nd+ sessions emit no lifecycle events and (because `BiometricStreamClient._currentSessionId` was cleared on the 1st `end`) record no biometrics.

## Target
In `_onState`, change the `active → idle` branch from `_channel.end(); _ended = true;` to:
```
_channel.end(); _started = false; _ended = false;
```
so the next `idle → active` fires a fresh `start()`. This inlines breath's `reset()` re-arm. Add a comment cross-referencing `BreathModuleStateChannel.reset()` so the parallel is explicit, not ad-hoc.

## Guards
- Keep the `status == _previousStatus` dedup and the start branch untouched.
- Dispose invariant must still hold: re-armed-while-idle → `_started == false` → no spurious `stop()`; active-then-navigate-away → `_started == true && !_ended` → `stop()` fires.

## Files
- `lib/MeditationModule/Core/MeditationModuleStateChannel.dart` (one file).

## Verify
On-device: Start → Stop → Start → navigate away — confirm the 2nd lifecycle is opened and closed correctly (start + end events for both sessions; biometrics recorded for both).
