# Stream biometric samples through pause

**Date:** 2026-06-19
**Source:** conversation context

## Key Findings

- `BiometricStreamClient.sendBatch` drops every batch while paused: `if (_currentSessionId == null || _isPaused) return;` (`lib/Biometrics/BiometricStreamClient.dart:95`). So a paused session has **zero** biometric data on the server.
- The device keeps producing samples through a pause; **two** gates suppress them — this client-side gate AND a server-side guard (`mind_api module-biometric-stream.grpc.controller.ts:132-139` drops the whole batch with `SESSION_PAUSED` while `session.isPaused`). HR/EEG during a pause is meaningful, and we want the pause interval rendered as a data-bearing region on the timeline (paired with note 124, which makes the pause a visible phase band).
- The session offset axis (note 121) is **continuous through pause** (the `Stopwatch` is never stopped), so biometric samples sent during a pause map to real, distinct offsets — no collapse. This is the reason the axis is not frozen on pause.

### Dependency

This requires the mind_api change (`mind_api/.ai-factory/notes/49-realtime-accept-samples-through-pause.md`) — the server biometric pause-guard removed — deployed **first**. Until then the mobile change is **inert**: samples leave the phone but the server rejects the batch with `SESSION_PAUSED`. Deploy order: server → mobile.

## Details

### Current state
- `_isPaused` is toggled in `_onLifecycleEvent` (`BiometricStreamClient.dart:80-83`): `true` on `ModuleSessionPaused`, `false` on `ModuleSessionUnpaused`/`ModuleSessionStarted`.
- It is read **only** in the `sendBatch` guard (line 95). Removing it from the guard makes the field inert for gating.

### The change
1. Change the `sendBatch` guard to gate solely on session liveness: `if (_currentSessionId == null) return;`.
2. `_isPaused` is now unused for gating — either delete the field and its `ModuleSessionPaused`/`Unpaused` assignments, or leave it inert (prefer deleting to avoid dead state). The `ModuleSessionEnded || ModuleSessionAbandoned` reset that clears `_currentSessionId` + replay ring stays.

### Guards
- Keep the `_currentSessionId == null` gate (ended/abandoned still suppress sends) and the ended/abandoned reset path (line 84-89).
- Do NOT touch the replay ring, the readiness gate (note 115), the 2 s reopen cooldown, or the connection-state teardown.
- One file: `lib/Biometrics/BiometricStreamClient.dart`.

## Open Questions

- None.
