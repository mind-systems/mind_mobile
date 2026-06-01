# Plan: Make meditation Stop reset the lifecycle (re-arm the state-channel) so each session is tracked

## Context
Meditation's one-shot `_started`/`_ended` flags never re-arm, so the 2nd+ Start→Stop cycle within a single screen mount emits no lifecycle events and records no biometrics. Re-arm both flags on the `active → idle` transition to mirror breath's `reset()`, so every session is tracked.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Re-arm lifecycle on Stop

- [x] **Task 1: Re-arm `_started`/`_ended` in the `active → idle` branch**
  Files: `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`
  In `_onState`, change the `active → idle` branch (currently `_channel.end(); _ended = true;`) to call `_channel.end()` then set `_started = false; _ended = false;`. This re-arms the channel so the next `idle → active` transition fires a fresh `_channel.start()` — inlining the re-arm that `BreathModuleStateChannel.reset()` performs (`lib/BreathModule/Core/BreathModuleStateChannel.dart:110-113`). Add a short comment on the re-arm lines cross-referencing `BreathModuleStateChannel.reset()` so the parallel is explicit.
  Keep the `status == _previousStatus` dedup (`:26`) and the `active && !_started` start branch (`:28-30`) untouched.
  Verify the dispose invariant still holds: after a Stop the channel is idle with `_started == false`, so `dispose()` (`:39`) fires no spurious `stop()`; an active session navigated away from has `_started == true && !_ended`, so `dispose()` still fires `stop()`.

## Verify
On-device: Start → Stop → Start → navigate away. Confirm both sessions open and close a lifecycle (start + end events for each) and biometrics are recorded for both, not just the first.
