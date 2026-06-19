# Eager-open data tunnels at connect

**Date:** 2026-06-19
**Source:** conversation context

## Key Findings

- The **state/control** tunnel already opens eagerly: `ModuleStateChannel._openSessionStream()` is called from the `connectionState` listener on `GrpcConnectionState.connected`, so it is subscribed long before any session command flows — which is exactly why it never races.
- The two **data** tunnels open lazily: `ModuleInstructionStream` opens only when `emit()` first runs (gated by `_streamRequested`), and `BiometricStreamClient` opens on the first `sendBatch()` (`_ensureSinkOpen`), listening only to `moduleStateEvents`, not to connection state. Lazy-open is the source of the cold-start race and of delivery logic leaking up into the modules.
- Making both data tunnels eager (open on `connected`, mirror the state tunnel, stay open for the app lifetime, reopen on reconnect) makes them warm before use and is the lifecycle counterpart to the readiness gate.
- **Eager-open is NOT a correctness mechanism on its own** — it is built on top of the readiness gate (notes 114/115). Without the gate, an eager reopen on reconnect would flush backlog into a not-yet-subscribed stream (same drop). With the gate, eager-open is safe and makes the gate's buffer almost always empty at session start (no first-phase latency).
- Mobile-only. The server controllers already accept a subscribed stream with no active session (they reject samples with `NO_SESSION`, but none flow while idle), and Phase 37 makes them emit `ready` on open regardless of session.

## Details

### Prerequisite

Notes 114 (instruction gate) and 115 (biometric gate) landed — they own the buffer-until-`ready` behavior that makes eager reopen safe across reconnect. Order: `mind_api` note 48 → 114 → 115 → this.

### `lib/Core/Grpc/ModuleInstructionStream.dart`

- Drop the lazy gate: in the `_connectionSub` `connected` case, call `_openStream()` unconditionally (today it is `if (_streamRequested) _openStream()`). Remove `_streamRequested` (or hardwire it true) so the tunnel opens at connect and reopens on every reconnect.
- `emit()` keeps its `_streamSink == null` fallback open path for safety, but in steady state the sink is already open by connect; pre-`ready` samples route to the outbox (note 114), post-`ready` go straight to the sink.

### `lib/Biometrics/BiometricStreamClient.dart`

- Inject the connection-state stream (via `GrpcConnectionManager`) alongside `moduleStateEvents`. Subscribe; on `connected` call `_ensureSinkOpen()`; on `disconnected` tear the sink down (reopen happens on the next `connected`). Keep the existing teardown on stream error/done.
- Keep the session gate in `sendBatch` (no-op without `_currentSessionId`) and the 2 s reopen cooldown — eager-open changes *when* the sink opens, not the no-samples-without-session rule. The replay ring + readiness gate (note 115) handle the rest.

### Wiring — `lib/Core/App.dart`

- Pass `connectionState` (from the `GrpcConnectionManager`/`GrpcClient` already built there) into `BiometricStreamClient`. `ModuleInstructionStream` already receives `connectionManager`.

### Idle-tunnel policy

Open always, for the whole app lifetime (mirrors the state tunnel). Accepted cost: ≈2 extra idle server subscriptions per connected user (already accepted in `mind_api` note 44). The biometric tunnel is idle when no biometric source exists; no samples flow without a session, so the idle stream is inert.

### Guards

- Mobile-only — no server change (controllers handle idle subscriptions; Phase 37 emits `ready` on open).
- Do NOT remove the readiness gate (notes 114/115) — eager-open depends on it for reconnect correctness; the gate must still re-arm on each `_openStream`/`_ensureSinkOpen`.
- Preserve the biometric session gate and the 2 s reopen cooldown.
- Logging only through `logPrint`. This task does not change buffering shape (that is the gate's job) and does not collapse the domain layer (note 117).

### Verify

Launch the app with no session: server `Realtime metrics: connectedStreams` reflects all three tunnels connected (state + instruction + biometric), and the data controllers' subscription is live before any session. Start a breath session: the first `rest` phase ships with no open-latency and the gate outbox is empty at send time. Force a reconnect mid-session: tunnels reopen on `connected`, the gate buffers across the gap, nothing is dropped.

## Open Questions

- None blocking. Whether to keep the biometric tunnel open when no BCI source is present is a non-issue — it is inert (no samples), and closing it conditionally would reintroduce lifecycle branching this task removes.
