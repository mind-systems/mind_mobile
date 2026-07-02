# Root/child — command addressing: `client_activity_id` on start + `session_id` on end/stop/pause/resume

**Date:** 2026-07-02
**Source:** conversation context; `mind_api/proto/module_state.proto`; handoff §10

## Key Findings

- With concurrent children the server needs the target child addressed explicitly. Proto adds optional `session_id` to `ActivityEnd/Stop/Pause/ResumeCmd` and optional `client_activity_id` to `ActivityStartCmd` — neither is populated by the client today.
- `session_id` omitted → server uses the sole live child, or errors `AMBIGUOUS_SESSION` if >1 child is live. So end/pause/resume/stop must carry the addressed child's id when concurrency is possible.
- `client_activity_id` is a client-generated idempotency token, **stable across retries** of the same logical start; the server dedups on key `${userId}:${clientActivityId}` within `idempotencyWindowMs` (**default 10 000 ms**, `mind_api/src/realtime/module-state.grpc.controller.ts:121-124` + dedup logic `:386-419`) and returns the same session instead of a duplicate. After the window there is no "already exists" guard (singleton guard removed for concurrent practices, mind_api note 06) — so the token must be reused, never regenerated, for a given logical start. (Separately, too many starts in `rateLimitWindowMs` (default 60 000 ms, `:117-120`) → `RATE_LIMIT_EXCEEDED`.)
- Depends on notes 13, 14. Feeds note 19 (start-race retry reuses the token).

## Details

### Current state (exact)
- `ModuleStateChannel.dart` builds commands without the new fields: start `:169-174`, pause `:180`, resume `:186`, end `:192-195`, stop `:200`.
- Adapters call `channel.start/pause/unpause/end/stop` with no per-child id: `BreathModuleStateChannel.dart` (start `:86-93`, pause `:101-106`, resume `:94-96`, end `:107-112`), `MeditationModuleStateChannel.dart` (start `:48-50`, end `:51-57`).

### Change
- Extend `ModuleStateChannel` command builders to accept and set `clientActivityId` (start) and `sessionId` (end/stop/pause/resume).
- Each adapter generates a stable `client_activity_id` at the moment of a logical start (e.g. a UUID stored on the adapter for that activity instance) and passes it on `start`; it stores its own child id (from the registry, note 14, matched by `activity_type`) and passes it as `session_id` on end/pause/resume/stop.
- Root adapter passes `client_activity_id` on its `start{ROOT}` too (idempotency), but has no end/stop.

### Guards
- Never regenerate `client_activity_id` for the same logical start (a fresh token defeats dedup → duplicate child).
- **Adopt an already-live child of the same type instead of starting a new one** — before sending `start`, check the registry (`childOfType`, note 14); if a live child of that `activity_type` exists (e.g. resumed after app restart / takeover), reuse it. The lost-on-restart token does not block or duplicate — the registry is the source of truth. Full rule + settling-window race in note 19.
- Send `session_id` only when it holds a real, owned, live child id; omit otherwise (do not send stale/empty). A frame tagged with an unowned/dead id is rejected `SESSION_NOT_FOUND`.
- Never target the root id with end/stop → `CANNOT_END_ROOT`.

### Verify
- Two live children (breath + meditation): `end` for one carries its `session_id`; the other stays live; no `AMBIGUOUS_SESSION`.
- Re-sending the same `start` with an unchanged token within the window returns the same child id (no duplicate).
