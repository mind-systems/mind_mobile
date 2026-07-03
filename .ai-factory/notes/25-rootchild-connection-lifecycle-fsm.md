# Root/child — connection-lifecycle FSM (kill the flag-soup)

**Date:** 2026-07-03
**Source:** conversation context; milestone-rescue diagnosis of the failed reconnect plan (`plan-reviews/23-*`)

## Key Findings

- The reconnect/eviction plan died in review by band-aiding: each round the reviewers surfaced another un-handled boolean interaction (`_yielded` not cleared on logout; pending-guards not reset in `_globalReset`; double-snackbar on one path). That is the signature of a **missing abstraction** — the connection's state was to be modelled as a pile of loose booleans (`_yielded`, `_supersededSeen`, `_backoffConfirmed`, plus the implicit "is the stream open") poked by hand in ~6 handlers, so every review found a path where one was mis-poked.
- Fix at the right level: give `ModuleStateChannel` an **explicit connection-lifecycle FSM** with named states and defined transitions, so eviction/reconnect/reset/takeover become transitions, not ad-hoc flag flips. This is the substrate the (re-planned) reconnect + start-race impls build on.
- **Behaviour-preserving.** This task lifts the *existing* connected/disconnected/onError/onDone/reset behaviour into the FSM under the current `module_state_channel_test.dart` golden master; it adds no new eviction behaviour. The `yielded` state exists but is **unreachable** until the reconnect impl wires `CONNECTION_SUPERSEDED` to it.

## Details

### Current state (exact)
- `ModuleStateChannel` reacts to `GrpcConnectionState` (`:55-64`, connected→`_openSessionStream`, disconnected→`_closeSessionStream`) and to stream `onError`/`onDone` (`:101-113`, both → close + `disconnect()` + `scheduleReconnect()`). Its state is implicit: `isConnected` = `_sessionSub != null` (`:40`), `_backoffConfirmed` (`:33`), and `ModuleState{idle,active}` (server-derived).
- No explicit "reconnecting" or "yielded" notion — the failed plan was about to bolt on `_yielded`/`_supersededSeen` booleans.

### Change
- Introduce `enum ConnectionLifecycle { disconnected, opening, active, reconnecting, yielded }` owned by the channel, plus a single `_transition(to)` chokepoint (log + guard). Map the existing paths onto it:
  - `GrpcConnectionState.connected` → `opening` → (first frame / `confirmConnected`, `:83-86`) → `active`.
  - `GrpcConnectionState.disconnected` / `onError` → `reconnecting` (backoff scheduled).
  - `onDone` (bare) → `reconnecting` (current behaviour).
  - `_reset()` (logout, `:222-226`) → `disconnected`, clearing all substate.
  - `yielded` — **defined, dormant**: no transition reaches it yet (the reconnect impl adds `SUPERSEDED → yielded` and gates `_openSessionStream` on it).
- Replace the implicit checks (`isConnected`, `_backoffConfirmed`) with FSM state where they read cleaner; keep the single bidi stream and `channel.events`/`channel.state` surface unchanged.

### Test scope (decompose-skeleton verdict — NO wholesale rewrite)
- The existing `module_state_channel_test.dart` (1347 lines, 11 groups) asserts on **observable** outputs — `channel.isConnected`, `confirmConnectedCount`, `disconnectCount`/`scheduleReconnectCount` (Group 7 `:891-963`), emitted events/state, outgoing metadata. A behaviour-preserving FSM lift keeps every one of these values identical, so **the golden master stays GREEN — do NOT rewrite it wholesale.** This task passes through the skeleton/TDD lens with no red-tests-first split: the transitions it introduces are already covered by the existing suite (the textbook "refactor under existing tests" case).
- Optional additive: assert each connected/disconnected/onError/onDone/reset path lands in the named `ConnectionLifecycle` state, and that `yielded` refuses reopen — small, on top of the green suite.
- **The wholesale `module_state_channel_test.dart` migrations (`:450`/`:532` header source, `:814` event) are NOT this task's** — they are driven by the reconnect impl's *behaviour* changes (note 20), which lands after and owns that blast-radius audit. The FSM lift changes structure, not behaviour, so it breaks no assertion.

### Guards
- **Behaviour-preserving** — the existing `module_state_channel_test.dart` suite must stay green (it is the golden master); this is a structural lift, not a behaviour change.
- Do NOT add eviction/yield behaviour here — `yielded` is dormant; wiring it is the re-planned reconnect impl's job.
- Do not fold the command-level pending-start guards (`_isPendingStart`/`_isPendingPause`) into this FSM — those are command lifecycle, owned by the start-race impl.

### Verify
- All existing `module_state_channel_test.dart` tests green (behaviour-preserving).
- Every connected/disconnected/onError/onDone/logout path resolves to exactly one FSM state; `yielded` is unreachable.
