# Root/child — `RootStateChannel`: open the root on connect, expose `root.id`

**Date:** 2026-07-02
**Source:** conversation context; `mind_api/.ai-factory/notes/34-deliver-root-id-on-connect.md`, `04-lazy-root-creation.md`

## Key Findings

- The root is a **client-started** session: the client sends `activity:start { activity_type: ROOT }` once the state stream is up and reads `root.id` from the response frame whose `activity_type == ROOT`. There is no unsolicited connect frame; a fresh connect with no command emits nothing (note 34 verify).
- `ensureRoot(userId)` is idempotent per user (note 04) — re-sending `start{ROOT}` always returns the same root. Safe to (re)send on every (re)connect.
- User decision: root is "just another module session, for the app itself" → model it as a **sibling adapter** to `BreathModuleStateChannel`/`MeditationModuleStateChannel`, differing only in: lifecycle tied to the connection (not a screen), and it **never** sends end/stop.
- The client needs `root.id` **only** to tag bio (note 17). Children are linked to the root server-side (`startActivity` stamps `rootSessionId`), so empty child sessions (no device) record regardless — root open is not gated on biodata (user decision).
- Depends on notes 13, 14.

## Details

### Current state (exact)
- No root concept on the client. `ModuleStateChannel` opens the bidi stream in `_openSessionStream` (`ModuleStateChannel.dart:72-80`) when auth/connection is up.
- Adapters (`BreathModuleStateChannel`, `MeditationModuleStateChannel`) each own one activity's lifecycle and read the shared state.

### Change
- Add `RootStateChannel` (app-level, wired at the DI layer in `App.dart` where `ModuleStateChannel` + `BiometricStreamClient` are constructed; not screen-scoped).
- **Trigger:** send `activity:start { activityType: root }` once the state stream is actually open — gate on `ModuleStateChannel.isConnected` (`ModuleStateChannel.dart:40`, `_sessionSub != null`) / the `GrpcConnectionState.connected` transition that runs `_openSessionStream` (`:55-58`). Sending before the sink exists is silently dropped (`_sendSessionRequest` `:206-207`), so send after stream-open and re-send on every connected transition (idempotent per user).
- **`ref_id` must be OMITTED for the root** (root has no ref, mind_api note 34 §Inlined contracts). Today `ModuleStateChannel.start` always sets `refId: refId ?? ''` (`ModuleStateChannel.dart:171`) — an empty string, not unset. Change the builder so a null `refId` leaves the optional proto field **unset** (do not send `''`); the root passes no `refId`. (This also fixes the `?? ''` smell the API side flagged; children still pass their real ref.)
- It reads `root.id` from the registry (`rootId` getter, note 14) — i.e. the frame with `activity_type == ROOT` — and exposes it as a `String? get rootId` + a stream, consumed by the bio client (note 17).
- Re-send `start{ROOT}` idempotently on each (re)connect; hold bio until `rootId` is known (note 17 gates on it).
- **This ROOT-start handshake is the sole source of `root.id`, on both first connect AND reconnect.** The reconnect fan-out emits per-child RESUMED only — **no root frame** (mind_api note 45) — so `rootId` must never be awaited from the resume fan-out; it always comes from the response to this adapter's own `start{ROOT}`. This makes `rootId` resolvable even on app-restart-mid-reconnect. See note 20.

### Guards
- Never send `activity:end`/`activity:stop`/pause/resume for the root — server rejects with `CANNOT_END_ROOT`. The root adapter has no end path at all.
- Do not gate root open on biodata (user decision — empty child sessions must still reach the server).
- Distinguish root by `activity_type == ROOT`, never by ordering or a connect push.

### Verify
- On connect, exactly one `start{ROOT}` is sent; `rootId` becomes non-null from the response frame.
- A second connect (reconnect) yields the same `rootId`, no duplicate root.
- Starting a breath child with no device still creates a child on the server (bio-empty), independent of `rootId`.
