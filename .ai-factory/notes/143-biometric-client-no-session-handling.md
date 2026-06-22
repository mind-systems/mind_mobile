# BiometricStreamClient reacts to a NO_SESSION error frame (stop the flood)

> **Superseded as the primary fix by note 153** (`gate biometrics on a confirmed session`). The proactive gate kills the flood at the source; this reactive teardown is kept as the defense-in-depth backstop for `INTERNAL_ERROR` / un-emitted edges. Retained as decision trace.

**Date:** 2026-06-22
**Source:** conversation context

## Key Findings

- `BiometricStreamClient` **logs and ignores** the server's `error` response frame. With a stale `_currentSessionId` and a buffered backlog after a background→resume, it floods hundreds of `NO_SESSION — No active session found` per minute with no backoff and never recovers (observed in production: 605/660/669 lines/min).
- Root cause: the `error` frame is a *valid stream message*, so the `onError`/`onDone` handlers (which tear the sink down) never fire. The `error` case must itself clear the dead session and stop sending.

## Details

### Current state
`lib/Biometrics/BiometricStreamClient.dart`:
- `:130-131` — the smoking gun:
  ```dart
  case $bio.BioStreamResponse_Event.error:
    logPrint('[BiometricStreamClient] error: ${r.error.code} — ${r.error.message}');
  ```
  No teardown, no session clear, no backoff.
- `:91-96` `sendBatch` already no-ops when `_currentSessionId == null`.
- `:143-150` `onError`/`onDone` → `_teardownSink()`, but never reached for error frames.
- `:82-86` `_currentSessionId` only clears on `ModuleSessionEnded`/`ModuleSessionAbandoned` lifecycle events — which today don't arrive when the server silently abandons (see note 144 / API note 62).

### Change
- `BioStreamResponse.error` is a `StateErrorEvent` (reused from `module_state.proto`); `code` is a **string**. The biometric controller emits exactly one terminal code: `emitError('NO_SESSION', 'No active session found')` (`mind_api/src/realtime/module-biometric-stream.grpc.controller.ts:119`); its only other code is `'INTERNAL_ERROR'` (`:165`).
- In the `BioStreamResponse_Event.error` case, branch on `r.error.code`:
  - **`r.error.code == 'NO_SESSION'`** (string, exact): `_currentSessionId = null`; `_replayRing.clear()`; `_teardownSink()`. `sendBatch` then no-ops → the flood stops immediately. (App-wide reset is note 144's job — this task only halts the client's own flood.)
  - Any other code (`'INTERNAL_ERROR'`): keep log-only (a bounded backoff is out of scope).
- Match the literal string `'NO_SESSION'` — `StateErrorEvent.code` is a proto `string`, not an enum (verified in `proto/module_state.proto:76-78`).

### Guards
- Don't break the `ready` (replay-drain) or `ack` cases, or the 2 s reopen cooldown (`_lastOpenAttempt`).
- Idempotent teardown; `_teardownSink()` already guards nulls.
- This stops the *flood* even if notes 144 / API-62 don't land; it does not by itself re-establish a session — that's the lifecycle reset (note 144).

### Verify
- Force a dead session (background past the server grace, then resume): at most a handful of NO_SESSION lines, then silence — not hundreds/min.

## Open Questions
- None — terminal code pinned to the literal string `'NO_SESSION'`.
