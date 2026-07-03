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
- **RE-PLAN on the refactor substrate (notes 25/26).** The first plan of this task died in review by band-aiding loose booleans; it is superseded. Express eviction/reconnect/reset as **`ConnectionLifecycle` FSM transitions** (note 25 — `SUPERSEDED` → `yielded`, `yielded` gates reopen, bare-close → `reconnecting`) and the whole-tree reset as **`SessionTerminated(reason)`** (note 26 — `movedToAnotherDevice` on eviction, `abandoned`/`rootDeath` on the reset paths), NOT ad-hoc `_yielded`/`_supersededSeen`/`AllSessionsReset` + two signals.
- **Comprehensive test-migration is mandatory (the rescue fix).** The header-source change (→ `root.id`) invalidates the header-metadata assertions `module_state_channel_test.dart:450,:532`; the termination changes invalidate the event assertion `:814`. Audit the **full** blast radius of every intended contract change and migrate **all** affected assertions in one pass — never piecemeal per review round (that whack-a-mole is exactly what stalled the first plan).

## Details

> **Written against the POST-refactor substrate (notes 25/26).** After the refactor, `ModuleStateChannel` owns a `ConnectionLifecycle` FSM (with a dormant `yielded` state) and a `SessionTerminated(reason)` event whose consumers are already wired. This task supplies what the refactor left dormant: the emitters, the `root.id` header, and reconcile-by-arrival. **Exact line numbers are re-pinned at plan time against the then-current (post-refactor) tree** — the pre-refactor `_openSessionStream` / `onDone` / `onError` / `session_error` handlers no longer stand alone; they are the FSM's transition chokepoint.

### Current state (post-refactor, symbolic)
- The header today carries the last **child** id (`currentState.moduleSessionId`); this task switches it to `root.id`.
- The FSM (note 25) has states `disconnected / opening / active / reconnecting / yielded`; `yielded` is **dormant** — no transition reaches it yet. This task adds the `→ yielded` transition and its reopen-refusal.
- `SessionTerminated(reason)` (note 26) exists with all consumers (adapters, bio, keep-alive reset; `GlobalListeners` reason→snackbar); **no emitter yet** — this task adds them.
- Server-side (unchanged, API): `handleReconnect` has two branches — memory-alive resumes root + all children by `userId` (ignores the header); memory-empty looks up the header id and returns generic `{abandoned:true}` if `ABANDONED`. `handleTransportDisconnect` graces the whole tree as a synchronized set. Reconnect cadence is `GrpcConnectionManager` backoff (1s→30s, cap 6, ±25% jitter), driven by connectivity-restored / app-resume / auth each calling `connect()`.

### Change (expressed as FSM transitions + `SessionTerminated`, NOT flags)
- **Header → `root.id`.** On (re)open, put `_registry.rootId` in the `module-session-id` metadata (only when known); read it **before** reconcile drops the pre-reconnect root.
- **Eviction classification lives in the `onDone` transition.** A `CONNECTION_SUPERSEDED` `session_error` observed on this stream is a per-stream transient input to that transition (reset when the FSM enters `opening`) — it is a transition guard, not a standalone latch:
  - close observed **with** SUPERSEDED → transition `→ yielded`, emit `SessionTerminated(movedToAnotherDevice)`; **no** `scheduleReconnect`. The evicted device yields.
  - close observed **without** it (bare — deploy/shutdown/auth-revoke) → transition `→ reconnecting` (`disconnect()` + `scheduleReconnect()`). The server rehydrates on restart, so the client MUST reconnect; must **not** yield. Self-correcting: a reconnect that is then evicted carries SUPERSEDED → yields then.
  - `onError` (transport drop) → `→ reconnecting` (unchanged path).
- **`yielded` refuses reopen.** The FSM rejects the `→ opening` transition while in `yielded`, so `GrpcConnectionManager` reopens (connectivity/app-resume/auth) are inert — the eviction war cannot restart. The **state**, not the connection manager, decides. Logout (`_reset`) transitions `yielded → disconnected`, so an evicted-then-logged-out device can reconnect on next login (the gap the first plan patched with a manual flag-clear is now a normal FSM transition).
- **`takeOverHere()` = the `yielded → opening` transition** (invoked from the passive "use here" UI). This device re-takes; the other gets SUPERSEDED and yields. The server returns a clean **root** frame with no children (children were ended server-side) — start fresh; do not expect the old children back.
- **Whole-tree reset → `SessionTerminated(reason)`.** The generic `{abandoned}` UNSPECIFIED frame → reset the registry + emit `SessionTerminated(abandoned)`; a root-level terminal (`COMPLETED`/`INTERRUPTED`/`ABANDONED`) = whole-tree death → reset + `SessionTerminated(rootDeath)`. Consumers (note 26) reset on any of these; the per-child `ModuleSessionAbandoned` path (single-child abandon) is unchanged. The reset must also clear the command-level pending guards so a reset landing mid-pending does not latch the next command.
- **Sequencing (reset-then-adopt)** is guaranteed by the server: on a lost-memory reconnect the client both learns `{abandoned}` (header fallback) and mints a new root via its own `start{ROOT}`; `handleReconnect` resolves in `setup()` **before** command subscription (`mind_api` note 34), so the ABANDONED frame precedes the new-root response. Apply reset first, then adopt the new root idempotently.
- **Reconcile-by-arrival** (this note's core logic; survives the refactor intact): on reopen, snapshot cached child ids, drop the pre-reconnect root immediately (so `rootId` is null until the note-15 ROOT re-open lands), arm a settling window; record real arrivals; when the window closes, evict every cached child that did not re-arrive. Tolerate one collapsed frame or many (per-child RESUMED is the API follow-up).
- **`root.id` via the note-15 ROOT re-open, NOT the fan-out** (the fan-out carries no root frame — mind_api note 45). **Trust `is_paused` from RESUMED frames** (mind_api Phase 62).
- **Comprehensive test-migration (the rescue fix).** The header-source change and the termination changes invalidate existing `module_state_channel_test.dart` assertions (`:450`/`:532` header source, `:814` event — line numbers re-pinned post-refactor). Audit the **full** blast radius and migrate **all** affected assertions in one pass — never piecemeal per review round.

### Guards
- Do not send a stale/child id in the header — send `root.id` only when known.
- Reset must be idempotent and clear the command pending guards.
- Yield is entered ONLY via the SUPERSEDED transition — a bare close must never reach `yielded`.
- Reconcile must tolerate one collapsed resume frame or many (until the API per-child RESUMED lands).
- Express everything as FSM transitions + `SessionTerminated(reason)` — do NOT reintroduce `_yielded`/`_supersededSeen` as free booleans poked across handlers, nor `AllSessionsReset` + separate signals.

### Verify
- Long disconnect past grace, memory lost → reconnect with `root.id` header → `{abandoned}` → `SessionTerminated(abandoned)` → adapters + bio reset → fresh root next connect.
- Reconnect within grace → per-child RESUMED rebuild the registry; `rootId` from the RootStateChannel re-open; live children survive with their real `is_paused`; no spurious reset.
- Second device connects → this device sees `CONNECTION_SUPERSEDED` then close → FSM `→ yielded`, `SessionTerminated(movedToAnotherDevice)`, moved-away UI; does **not** reopen across a background/resume cycle (the `yielded` state refuses `opening`). No ping-pong.
- Backend deploy → **bare** close (no SUPERSEDED) → FSM `→ reconnecting` → client reconnects + reconciles; NOT stranded.
- Evicted → logout → login → FSM left `yielded` on logout → reconnects normally.
- "Use here" → `yielded → opening` → clean RESUMED root, no children → fresh start; the other device yields.
- Airplane toggle (`onError`) while not yielded → `→ reconnecting` → registry rebuilt; session continues.
