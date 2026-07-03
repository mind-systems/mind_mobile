# Plan: Connection-lifecycle FSM (behaviour-preserving lift)

## Context
Replace `ModuleStateChannel`'s scattered implicit connection state (`isConnected`, `_backoffConfirmed`, plus the "is the stream open" notion) with an explicit `ConnectionLifecycle` FSM routed through a single `_transition` chokepoint — a pure structural lift that keeps every observable output of the golden-master test suite identical, with the `yielded` state defined but dormant for a later reconnect impl.

## Settings
- Testing: additive-only (existing golden master `test/Core/Grpc/module_state_channel_test.dart` must stay green; only small additive assertions are new)
- Logging: minimal (route all logs through `logPrint` per project logging rule; `_transition` logs each state change)
- Docs: no

## Constraints (from spec note `.ai-factory/notes/25-rootchild-connection-lifecycle-fsm.md`)
- **Behaviour-preserving.** Every value the existing suite asserts on — `isConnected`, `confirmConnectedCount`, `disconnectCount`/`scheduleReconnectCount`, emitted events/state, outgoing metadata — must remain identical. Do NOT rewrite the golden master.
- **`yielded` is dormant** — defined in the enum but no transition reaches it in this milestone. Wiring `SUPERSEDED → yielded` and gating `_openSessionStream` on it is the later reconnect impl's job.
- **No new eviction/yield behaviour** here.
- **Do NOT fold** the command-level pending guards (`_isPendingStart` / `_isPendingPause`) into this FSM — those are command lifecycle, owned by the start-race impl. They stay exactly as-is.

## Tasks

### Phase 1: FSM substrate

- [x] **Task 1: Define the `ConnectionLifecycle` enum**
  Files: `lib/Core/Grpc/ConnectionLifecycle.dart`
  Create a new one-type-per-file enum (mirroring the existing `lib/Core/Grpc/GrpcConnectionState.dart` / `ModuleState.dart` convention): `enum ConnectionLifecycle { disconnected, opening, active, reconnecting, yielded }`. Add a short doc comment on the enum and on each value describing the connection meaning, and explicitly note that `yielded` is defined-but-dormant (no transition reaches it until the reconnect impl wires `CONNECTION_SUPERSEDED`).

- [x] **Task 2: Add the lifecycle field and `_transition` chokepoint** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Import `ConnectionLifecycle`. Add a private field `ConnectionLifecycle _lifecycle = ConnectionLifecycle.disconnected;`. Add a single private method `void _transition(ConnectionLifecycle to)` that is the sole mutation point for `_lifecycle`: it logs the change via `logPrint` (e.g. `'[ModuleStateChannel] lifecycle: $_lifecycle → $to'`), then assigns. Keep it side-effect-free beyond logging + assignment (no stream/socket calls inside `_transition`). Do not route any behaviour through it yet — that is Task 3.

### Phase 2: Route existing paths through the FSM

- [x] **Task 3: Map connected/disconnected/onError/onDone/reset onto the FSM and retire the implicit flags** (depends on Task 2)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Route each existing path through `_transition`, preserving behaviour exactly:
  - `_openSessionStream()` (`:90`): `_transition(ConnectionLifecycle.opening)` at the point that currently sets `_backoffConfirmed = false`. Keep opening the sink/subscription and firing `_sessionStreamOpened` unchanged.
  - First received frame (`:101`, the `if (!_backoffConfirmed)` gate): replace the `_backoffConfirmed` boolean with the FSM — when `_lifecycle == ConnectionLifecycle.opening`, `_transition(ConnectionLifecycle.active)` then call `_connectionManager.confirmConnected()`. This must keep `confirmConnected` firing **exactly once per stream open** (Group at `:891`): once opening→active happens, later frames see `active` and skip. Remove the `_backoffConfirmed` field entirely.
  - `onError` (`:120`) and `onDone` (`:126`): after `_closeSessionStream()` + `disconnect()` + `scheduleReconnect()` (order and calls unchanged), `_transition(ConnectionLifecycle.reconnecting)`.
  - `GrpcConnectionState.disconnected` handler (`:77`): after `_closeSessionStream()`, `_transition(ConnectionLifecycle.reconnecting)`.
  - `_reset()` (`:325`, logout/GuestState): `_transition(ConnectionLifecycle.disconnected)` alongside clearing substate. `_reset` must land in `disconnected`, not `reconnecting`.
  - `isConnected` getter (`:51`): keep its observable result **identical** to `_sessionSub != null` (true while `opening` or `active`, false otherwise). Either derive it from `_lifecycle` with an equivalent predicate or leave it backed by `_sessionSub` — whichever keeps the golden-master `isConnected` assertions (`:850`, `:934`, `:1099`, `:1027`) green.
  - `yielded`: leave unreachable. Add a brief comment at `_openSessionStream` noting where the future reconnect impl will gate reopen on `yielded`; do not add that gate now.
  - Do NOT touch `_isPendingStart` / `_isPendingPause` or any command guard.

### Phase 3: Additive coverage

- [x] **Task 4: Add additive FSM-state assertions on top of the green suite** (depends on Task 3)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`, `test/Core/Grpc/module_state_channel_test.dart`
  Expose the FSM for assertion via a `@visibleForTesting ConnectionLifecycle get lifecycle => _lifecycle;` getter on `ModuleStateChannel` (import `package:flutter/foundation.dart` for the annotation, matching existing test-visible accessors if any). Add a small new test group asserting that each path resolves to exactly one expected state: connected→(first frame)→`active`, connected-before-first-frame→`opening`, `disconnected`→`reconnecting`, stream `onError`/`onDone`→`reconnecting`, logout/GuestState→`disconnected`. Add one assertion that `yielded` is never reached by any of these paths (it stays dormant). Do NOT modify or rewrite any existing group — only append. Run the full suite and confirm it is green.
