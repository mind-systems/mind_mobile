# Plan: Emit pause/resume as `breath_phase` boundary markers on the offset timeline

## Context
Make the pause interval a first-class phase band on the continuous offset timeline by emitting `phase='pause'` and explicit resume-phase boundary markers into the existing `breath_phase` instruction stream — so mind_web can draw the pause region without a new instruction type.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Pause/resume boundary markers

> **Dependency (deploy order):** server must ship first. This requires `mind_api` note 49 (instruction pause-guard removed). Until the server guard is gone, the resume marker is rejected with `SESSION_PAUSED` (on resume the server is still `isPaused=true`). The mobile change is safe to write before the server deploys but will not function end-to-end until then.
>
> All work is in `lib/BreathModule/Core/BreathModuleStateChannel.dart`. Reuse the existing `_stopwatch` (note 121), `_wireTimestamp`, `_moduleSessionId`, and `BreathModuleInstructionStream.sendSample(sessionId, phase, tickCount, offsetMs, timestampMs)` — no signature changes to `sendSample`, no new `instructionType`. The wire `data.phase` is a string, so `'pause'` (not a `BreathPhase` enum member) is valid as-is.

- [x] **Task 1: Add a marker-emit helper and widen `_handleLifecycle` to receive the full state**
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  Add a private `void _emitMarker(String phaseName, int tickCount, int offsetMs)` that resolves `_moduleSessionId`; if it is `null`, log a minimal warning (`[BreathModuleState] dropping <phaseName> marker — no moduleSessionId yet [$_sessionId]`) and return; otherwise call `_instructionStream.sendSample(sessionId, phaseName, tickCount, offsetMs, _wireTimestamp(offsetMs))`. (Skipping when `null` is acceptable here: pause/resume occur only after session start, by which point the module session id is established and pending instructions have flushed.)
  Change `_handleLifecycle(BreathSessionStatus status)` to `_handleLifecycle(BreathSessionState state)` and update the call in `_onState` (pass `state`; derive `status` locally as `state.status`). Keep all existing lifecycle branches behaving exactly as before.

- [x] **Task 2: Emit a `phase='pause'` marker on the active→pause transition** (depends on Task 1)
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  In the `wasActive && status == BreathSessionStatus.pause` branch (inside the `_started && !_ended` guard), alongside the existing `_channel.pause()` call, emit `_emitMarker('pause', 0, _stopwatch.elapsedMilliseconds)`. `tickCount` is meaningless for a pause marker, so send `0`. Do **not** alter or remove `_channel.pause()` — the server PAUSED lifecycle event is a separate axis (status/recovery) and must stay.

- [x] **Task 3: Explicitly re-emit the resumed phase marker on resume** (depends on Task 2)
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  In the resume branch (`wasPaused && isActive`, `else` arm where `_started` is already true), after `_channel.unpause()`, explicitly emit the current phase marker — do **not** rely on `phaseChanged`, because the phase is unchanged across the pause so `_handleInstruction` will not fire. Use `_emitMarker(state.phase.name, state.currentPhaseTotalDuration, _stopwatch.elapsedMilliseconds)`, mirroring the existing `_handleInstruction` emit. Then set `_previousPhase = state.phase` and `_previousExerciseIndex = state.exerciseIndex` so a later real phase change still diffs correctly and is not swallowed. (Note: `_onState` also assigns these at the end of the tick; setting them here keeps intent explicit and is harmless. Since `phaseChanged` is `false` on resume, the subsequent `_handleInstruction` call returns early and will not double-emit.)
