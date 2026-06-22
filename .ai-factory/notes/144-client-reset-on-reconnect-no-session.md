# Client resets module-session on server-reported session death (reconnect/abandon)

> **Superseded by note 154** (`handle the ABANDONED confirmation`). This note predates the client-confirmed abandonment contract (mind_api note 62) and treated `sessionError.code=='no_active_session'` as a death signal; note 154 corrects that to a defensive no-op reset and makes the `ABANDONED` sessionState the authoritative trigger. Retained as decision trace.

**Date:** 2026-06-22
**Source:** conversation context

## Key Findings

- On resume, the transport reconnects and `ModuleStateChannel` re-opens the `trackActivity` stream, but the client **never learns its server session is gone**: the server sends nothing on reconnect-with-no-session (fixed server-side by API note 62), `ModuleStateChannel` swallows `DISCONNECTED` (`:84`) and only logs `sessionError` (`:86-87`). So `_currentSessionId` in `BiometricStreamClient` stays set and the breath/meditation channels still think they're active.
- Make a server-reported session-gone signal **authoritative**: emit `ModuleSessionAbandoned`, reset to `ModuleState.initial()`, and re-arm the module channels so streaming stops and a fresh session can start on the next activity.

## Details

### Current state
`lib/Core/Grpc/ModuleStateChannel.dart`:
- `:82-90` — `sessionState` with `DISCONNECTED` → early `return` (swallowed); `sessionError` → `logPrint` only.
- `:116-145` `_processProtoEvent` — already maps `ABANDONED` → `_state.add(ModuleState.initial())` + `_events.add(ModuleSessionAbandoned())` (`:136-138`). So once the server actually *sends* `ABANDONED` (API note 62), the biometric reset path works.
- `BreathModuleStateChannel` / `MeditationModuleStateChannel` observe **ViewModel** state, tracking `_started`/`_ended` flags (`MeditationModuleStateChannel:38-46`); they don't currently react to `ModuleSessionAbandoned`, so after an abandon their flags can stay stale and suppress the next `ActivityStart`.

### Authoritative codes (pinned)
`StateErrorEvent.code` is a proto `string` (`module_state.proto:76-78`). Control-stream `session_error` codes the server actually emits (`mind_api/src/realtime/module-state.grpc.controller.ts` + `services/activity-engine.service.ts`):
- **Session-dead → reset:** `'no_active_session'` (`WsErrorCode.NO_ACTIVE_SESSION`, thrown by pause/unpause on a gone session, `activity-engine.service.ts:340,372` → controller `:356,381`).
- **Transient → log-only (unchanged):** `'INTERNAL_ERROR'`, `'INVALID_COMMAND'`, `'RATE_LIMIT_EXCEEDED'`, `'INVALID_ACTIVITY_TYPE'`, `'already_paused'`, `'not_paused'`.
- The **primary** session-death signal is not a `session_error` at all but a `sessionState{ status: ABANDONED }` event (API note 62) — already mapped at `ModuleStateChannel.dart:136-138`.

### Change (client half; consumes API note 62)
1. Handle `sessionError` (`:86-87`): if `r.sessionError.code == 'no_active_session'`, treat it like `ABANDONED` — `_state.add(ModuleState.initial())` + `_events.add(ModuleSessionAbandoned())`. All other codes stay log-only.
2. Ensure `BreathModuleStateChannel` and `MeditationModuleStateChannel` **re-arm** (`_started = false; _ended = false`) on `ModuleSessionAbandoned` so a new `ActivityStart` is not suppressed by stale flags. (They may need to subscribe to the channel's `ModuleStateEvent` stream for this.)
3. The existing `ABANDONED` → `ModuleSessionAbandoned` path already clears `BiometricStreamClient._currentSessionId` (`:82-86`) and the FGS keep-alive (note 139) — verify it fires end-to-end once the server sends `ABANDONED` on reconnect.

### Guards
- Depends on **API note 62** (server sends `ABANDONED` in the reconnect-with-no-session branch).
- Do **not** disturb the normal `RESUMED` reconnect path (when a session IS recoverable) — only the gone-session case resets.
- Map the right `sessionError`/`ActivityStatus` codes; don't reset on transient errors.
- Complements note 143 (biometric client self-halts the flood); this task is the app-wide state reset + re-arm.

### Verify
- Background past the server grace → resume → client logs a single abandon, the NO_SESSION flood stops, biometric/keep-alive teardown runs, and starting a new session immediately works (no suppressed `ActivityStart`).

## Open Questions
- None — codes pinned above (`'no_active_session'` resets; `ABANDONED` sessionState is the primary signal).
