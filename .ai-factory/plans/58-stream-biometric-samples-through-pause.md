# Plan: Stream biometric samples through pause

## Context
Let biometric samples (HR/EEG) keep streaming to the server during a paused session by gating `sendBatch` solely on session liveness instead of also dropping on pause. The change is inert until the `mind_api` server-side pause-guard (Phase 39 / note 49) is removed and deployed.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Drop the pause gate

- [x] **Task 1: Gate `sendBatch` on liveness only and remove `_isPaused`**
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  - Change the `sendBatch` guard (line 95) from `if (_currentSessionId == null || _isPaused) return;` to `if (_currentSessionId == null) return;`. Keep the `if (samples.isEmpty) return;` line and the `_ensureSinkOpen()` / `_encodeAndAdd(samples)` calls unchanged.
  - Delete the `bool _isPaused = false;` field declaration (line 31).
  - In `_onLifecycleEvent` (lines 74–90): remove the `_isPaused = false;` assignment from the `ModuleSessionStarted` case (keep `_currentSessionId` and `_lastOpenAttempt` assignments); delete the entire `ModuleSessionPaused()` case and the entire `ModuleSessionUnpaused()` case (lines 80–83); in the `ModuleSessionEnded() || ModuleSessionAbandoned()` case remove the `_isPaused = false;` line while keeping `_currentSessionId = null;`, `_lastOpenAttempt = null;`, and `_replayRing.clear();`.
  - Do NOT touch: the replay ring, the readiness gate (`_isReady`/`_readyTimer`, note 115), the 2 s reopen cooldown (`_lastOpenAttempt` in `_ensureSinkOpen`), or the connection-state teardown path.
  - Update the class doc comment (lines 16–18) so it no longer says `sendBatch` is a no-op "or the session is paused" — it is now a no-op only when there is no active session.
  - `ModuleSessionPaused` / `ModuleSessionUnpaused` must remain valid `ModuleStateEvent` variants in the codebase (they are still used elsewhere); only this client's handling of them is removed — do not delete the event types.

- [x] **Task 2: Confirm analyzer cleanliness** (depends on Task 1)
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  After the edit, run `/usr/local/bin/flutter analyze lib/Biometrics/BiometricStreamClient.dart` to confirm there are no unused-field/unhandled-case warnings (the switch on `ModuleStateEvent` must still handle every remaining variant exhaustively, or use a default if the enum/sealed type requires it). Fix any analyzer issues introduced by the removal.

## Notes
- Deploy order is server → mobile; this mobile change produces no observable behavior change until the `mind_api` biometric pause-guard (`module-biometric-stream.grpc.controller.ts:132-139`) is removed. That server work is out of scope for this milestone.
- Single commit: "Stream biometric samples through paused sessions".
