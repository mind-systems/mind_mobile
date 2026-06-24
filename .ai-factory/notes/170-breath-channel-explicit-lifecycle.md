# Feed BreathModuleStateChannel an explicit lifecycle instead of parsing status (T6)

**Date:** 2026-06-24
**Source:** conversation context (breath lifecycle FSM refactor planning)

## Key Findings

- `BreathModuleStateChannel._handleLifecycle` (`lib/BreathModule/Core/BreathModuleStateChannel.dart:70-110`) **re-derives** the activity lifecycle from `status` transitions: it computes `isActive` (`breath||rest`, `:74`), `wasActive`, `wasPaused` (`:76-79`) and maps `pause ↔ active ↔ complete` to the server commands `start`/`unpause`/`pause`/`end` (`:81-109`), tracking its own `_started`/`_ended` (`:16-17`). This is the **third** reconstruction of "is the activity live" (alongside `_hasStarted` in the SM and `ModuleState` on the server).
- This adapter is **not** in the refactor's blast radius — its server-session job stays — but once `BreathSessionState.lifecycle` exists ([[167-breath-derive-lifecycle-islive]]) it should read the **explicit** signal (`stop | pause | play` ≈ notStarted/completed | paused | running) rather than parse `status` meanings. This formalizes the one accepted cross-layer leak into a clean contract: the backend stops interpreting state, we tell it the state.

## Details

Switch `_handleLifecycle` to branch on `state.lifecycle` transitions instead of `state.status`:
- `notStarted → running` ⇒ `_channel.start` (first activation) / `_channel.unpause` (subsequent);
- `running → paused` ⇒ `_channel.pause`;
- `→ completed` ⇒ `_channel.end`.

Keep `_started`/`_ended`, the stopwatch + origin wall-clock, the instruction-stream marker emission (`_emitMarker`/`_handleInstruction`), `_flushPending`, `reset()`, and `dispose() → stop` **exactly as-is** — only the **input discriminator** changes. The breath/rest distinction the instruction path still needs reads from `state.phase`, not `status`.

## Guards

- Behavior must be byte-identical. The existing `breath_module_state_channel_test.dart` (its golden master) stays **green** with at most a feed-shape change (emitted states now carry `lifecycle`; if `status` is kept derived through [[171-breath-extract-owned-lifecycle-fsm]], the test may need zero edits).
- Do **NOT** rewrite the server logic, instruction stream, pending-flush, or `reset()`. The backend stays server-gated; this is an input substitution, not a re-architecture.

## Verify

- Full `breath_module_state_channel_test.dart` green; identical `start/pause/unpause/end/stop` call sequences for every transition.
