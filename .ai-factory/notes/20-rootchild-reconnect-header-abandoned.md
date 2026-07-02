# Root/child — reconnect via `root.id` header + abandoned/reconcile handling

**Date:** 2026-07-02
**Source:** conversation context (decision #1); `mind_api/src/realtime/services/activity-engine.service.ts:604-654` (`handleReconnect`)

## Key Findings

- Server `handleReconnect` has two branches: (1) memory alive (`sessionIds.length > 0`) → resumes root + all children by `userId`, **ignores** the `module-session-id` header; (2) memory empty → looks up the header id in the DB and returns a generic `{ abandoned: true }` if that row is `ABANDONED`.
- `handleTransportDisconnect` puts root + every child on a grace timer from the same disconnect instant → the whole tree is abandoned as a **synchronized set**.
- Decision #1: keep the header (we need the abandoned signal to know when to reset), and carry **`root.id`** in it (not the last child as today). Rationale: the abandoned return is generic; root death ⟺ whole-tree death; a single header slot maps naturally to the single root; the client always holds `root.id` (from `start{ROOT}`).
- Today the header carries the last known **child** id (`ModuleStateChannel.dart:72-79`).
- **Connection model is single-stream-per-user, last-connect-wins (API decision, finalized).** Only one realtime state stream per user is live; a newer connection (another device, or a fresh app instance) takes over and the API **evicts** the previous one with a concrete signal: on the STATE stream it sends `session_error { code: 'CONNECTION_SUPERSEDED' }` **then closes the stream** (graceful). Eviction key is `(userId, service)` server-side — **no client connection id needed.**
- **On eviction the server ENDS the evicted connection's child practices** (terminal + `disconnectedAt`) but **keeps the ROOT alive** for the new connection. So the taking-over device gets a **clean root, no phantom children** — on an explicit takeover it receives a RESUMED **root** frame with no child frames and starts fresh.
- **Ping-pong is the danger:** if the evicted device auto-reconnects it re-evicts the other side → infinite eviction war between two online devices. **The evicted device MUST yield** (go passive, no auto-reconnect) until an explicit user "use here" action. This is mandatory, not optional.
- Depends on notes 14, 15. Pairs with note 19 (reconcile-by-arrival). API follow-up (per-child RESUMED) makes the resume branch fully explicit.
- **This is the IMPL milestone.** The eviction/reconnect invariants + red scenarios are part of the **combined concurrency contract milestone (note 24)** laid first; this task turns the eviction/reconnect half green.

## Details

### Current state (exact)
- `ModuleStateChannel._openSessionStream` (`ModuleStateChannel.dart:72-80`): if `currentState.status == active` and `liveId = currentState.moduleSessionId` (the last child) is non-empty, opens with `CallOptions(metadata: {'module-session-id': liveId})` (`:76-79`).
- **`onError` and `onDone` are currently identical** (`ModuleStateChannel.dart:101-106` and `:107-113`): both `_closeSessionStream()` + `_connectionManager.disconnect()` + `_connectionManager.scheduleReconnect()`. No graceful-vs-drop distinction exists — this task adds it.
- **`session_error` handling** (`:92-96`) only branches on `'no_active_session'` today (→ `ModuleState.initial()`); `'CONNECTION_SUPERSEDED'` is unhandled — this task adds it. There is **no `_yielded` latch** today; the reopen (`_openSessionStream` `:72`) is unconditional on `GrpcConnectionState.connected`.
- Reconnect drives from `GrpcConnectionManager`: exponential backoff `initialDelay 1s → maxDelay 30s`, exp cap 6, ±25% jitter (`GrpcConnectionManager.dart:117-129`, `BackoffConfig.dart:12-13`); connectivity-restored (`:61-68`), app-resume (`:70-75`), and auth (`:52-55`) each call `connect()`.
- Abandoned handling today: each adapter/bio subscribes to `channel.events` and reacts to `ModuleSessionAbandoned` individually — `BreathModuleStateChannel.dart:50-52` (`reset()`), `MeditationModuleStateChannel.dart:32-39` (field reset), `BiometricStreamClient.dart:100-104` (clear session id + replay ring). The snackbar is raised via `GlobalListeners` (`docs/core/global-listeners.md`).

### Change
- Send `root.id` in the `module-session-id` header on (re)open (`ModuleStateChannel.dart:75-79`), replacing `currentState.moduleSessionId` (the last child).
- Handle the generic abandoned signal as a **global reset** via the **existing `channel.events` broadcast** (`ModuleStateChannel._events`, `:23`): add one new `ModuleStateEvent` subtype (e.g. `AllSessionsReset`) that every adapter + bio already-subscribed to `channel.events` handles by resetting (breath `reset()` `BreathModuleStateChannel.dart:144-155`, meditation field reset `:33-38`, bio clear id + replay ring `BiometricStreamClient.dart:100-104`). Do **not** invent a separate broadcast channel — reuse `channel.events`. The next connect re-opens a fresh root (note 15).
- **Sequencing (reset-then-adopt) is guaranteed by the server:** on a lost-memory reconnect the client both learns `{abandoned}` (old root, via the header fallback) **and** mints a new root via its own `start{ROOT}` (note 15). The server resolves `handleReconnect` in `setup()` **before** it subscribes to client commands (`mind_api` note 34 §Change: `ensureRoot`/reconnect resolves between the reconnect block and `request.subscribe`), so the ABANDONED frame is emitted **before** the new-root response. The client applies global-reset first, then adopts the new root — and must treat a fresh root id arriving after a reset idempotently (reset clears the registry; the new ROOT frame repopulates it).
- **Reconcile-by-arrival** on the resume branch: rebuild the registry from the per-child RESUMED/ACTIVE frames that actually arrive; any locally-cached child that gets no frame within the settling window is treated as gone (feeds note 19's retry / reset). Do not assume a single resume frame.
- **`root.id` is (re)learned from the note-15 ROOT re-open, NOT from the reconnect fan-out.** Per mind_api note 45, the reconnect fan-out emits **per-child RESUMED only — no root frame**. `RootStateChannel` re-sends `activity:start{ROOT}` idempotently on every (re)connect and gets the root frame in response to its own start, so `rootId` is always resolved even on app-restart-mid-reconnect. Reconcile must therefore source `rootId` from the RootStateChannel cache/re-open, never expect it in the resume fan-out.
- **Trust `is_paused` from RESUMED frames.** mind_api Phase 62 (durability) now backs a truthful `is_paused` on reconnect (previously hardcoded `false`), so reconcile can adopt each resumed child's real paused state instead of assuming active.
- **SUPERSEDED branch — the mandatory ping-pong fix. Yield ONLY on an actual `CONNECTION_SUPERSEDED`, never on a bare close.** Today the `session_error` handler only checks `'no_active_session'` (`ModuleStateChannel.dart:92-96`) and `onDone`/`onError` are identical (`:101-113`). Change:
  - **Track a per-stream flag `_supersededSeen`** (reset to `false` in `_openSessionStream` alongside `_backoffConfirmed`, `:72-73`). On `session_error { code: 'CONNECTION_SUPERSEDED' }` (`:92-96`) set `_supersededSeen = true` — do not act yet; the graceful close follows.
  - **On `onDone` (`:107-113`), branch on the flag:**
    - `_supersededSeen == true` (eviction) → set the **`_yielded = true`** latch, `_closeSessionStream()`, emit `AllSessionsReset` / "session moved" so adapters go passive and bio clears. **Do NOT `scheduleReconnect()`.** The evicted device yields.
    - `_supersededSeen == false` (**bare graceful close** — server shutdown/deploy, or auth revoke) → **treat as transient: `disconnect()` + `scheduleReconnect()`** (reconcile path). The server rehydrates sessions on restart, so the client MUST reconnect — must NOT latch yield. Self-correcting: if that reconnect is itself evicted, its close carries `CONNECTION_SUPERSEDED` → yield then.
  - **Guard the reopen with the latch:** `_openSessionStream` (`:72`) early-returns while `_yielded` is true, so the `GrpcConnectionManager`-driven reopens (connectivity-restored `GrpcConnectionManager.dart:61-68`, app-resume `:70-75`, auth `:52-55`) **cannot silently re-take** the session — app-resume must not restart the eviction war. The latch, not the connection manager, decides.
  - **Clear the latch only on explicit user action:** add a `takeOverHere()` entry point (invoked from the passive "use here" UI) that sets `_yielded = false` and reopens the stream → this device takes over, the other gets SUPERSEDED and yields. On this takeover the server returns a clean **root** frame with no children (children were ended server-side) — start fresh; do not expect the old child sessions back.
  - **`onError` (connectivity loss / transport drop)** ⇒ genuine disconnect, unchanged: keep `:101-106` (`_closeSessionStream()` + `disconnect()` + `scheduleReconnect()`); the reconnect + reconcile path of this note applies.
  - **Auth revoke stays in the auth layer** (`GrpcAuthInterceptor` → `LogoutNotifier` → `GlobalListeners`, per `docs/core/jwt-authentication.md`) — it closes the stream bare (no code), which correctly falls into the reconnect branch here and must **not** latch yield; the logout flow tears things down independently.

### Guards
- Do not send a stale/child id in the header — the generic abandoned fallback would fire against the wrong session; send `root.id` only when known.
- Global reset must be idempotent and not double-fire per child.
- Until the API per-child RESUMED lands, the resume branch may deliver one collapsed frame — reconcile must tolerate both (one frame or many).

### Verify
- Long disconnect past grace, server memory lost → reconnect with `root.id` header → `{abandoned}` → all adapters + bio reset → fresh root on next connect.
- Reconnect within grace → per-child RESUMED frames rebuild the registry; `rootId` comes from the RootStateChannel re-open (not the fan-out); live children survive with their real `is_paused`; no spurious reset.
- Second device connects → this device receives `session_error{CONNECTION_SUPERSEDED}` then graceful close → `_yielded` set, adapters passive, moved-away UI shown; client does **not** auto-reconnect even across an app background/resume cycle (latch gates `_openSessionStream`). No eviction ping-pong.
- **Backend deploy / restart** → stream closes **bare** (no `CONNECTION_SUPERSEDED`) → `_supersededSeen` is false → client **reconnects** + reconciles; the client is NOT stranded in the passive state.
- Auth revoke → bare close → reconnect branch here does not latch; the auth layer drives logout independently.
- After eviction, tapping "use here" → `takeOverHere()` clears the latch, reopens → RESUMED **root** frame arrives with **no** child frames → this device starts fresh; the other device now gets SUPERSEDED and yields.
- Transport drop (airplane mode toggle, `onError`) while NOT yielded → auto-reconnect → registry rebuilt from RESUMED frames; session continues on this device.
