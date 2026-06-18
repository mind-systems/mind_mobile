# Instruction stream readiness gate (client) — buffer until server `ready`

**Date:** 2026-06-18
**Source:** conversation context — note 44 verified empirically (logs + DB)

## Key Findings

- The first instruction frame (`rest`) is dropped on every freshly-opened instruction tunnel: the client adds it to the sink in the same instant the tunnel opens, before the server's post-auth `request.subscribe()` runs, so the NestJS gRPC adapter loses it. Proven: DB has no `rest` row for the reproduced session; server `next()` first fired on the *second* phase.
- The client currently fires its flush trigger on **local** stream open — `ModuleInstructionStream._openStream()` ends with `_readyController.add(null)`, which drives `BreathModuleInstructionStream.flushBuffer()`. This flushes into a stream the server has not yet subscribed to. The trigger must move from *local open* to *server readiness*.
- **Reconnect mid-session hits the identical race** — on re-open the client flushes its backlog into a not-yet-subscribed stream. The gate must be **open-agnostic**: it re-arms on every `_openStream` (cold-start and reconnect alike).
- The readiness signal is **server→client** (new `ready` arm in `StreamResponse.event`, added by mind_api note 48). The client subscribes to the response stream synchronously in `_openStream`, so it always receives `ready`. A client-sent probe would be dropped like `rest` — do not use one.

## Details

### Prerequisite

mind_api note 48 deployed first (server emits `ready`). Copy the updated `proto/module_instruction_stream.proto` into `mind_mobile/proto/` and run `./scripts/gen_proto.sh` so the generated `StreamResponse` carries the `ready` arm. This proto copy + regen is bundled in this task (first consumer); the biometric gate (note 115) reuses the regenerated stubs.

### The gate — `lib/Core/Grpc/ModuleInstructionStream.dart`

Move the authoritative race guard into the transport layer:

- Add `bool _isReady = false;` and a transport-level outbox `final List<StreamSample> _outbox = [];`.
- `_openStream()`: set `_isReady = false`, `_outbox.clear()` (re-arms the gate for cold-start AND reconnect). **Remove** the `_readyController.add(null)` call from the end of `_openStream` — readiness is no longer "local open".
- Response listener: handle the new `StreamResponse_Event.ready` — set `_isReady = true`, update `_maxSamplesPerSecond` from `ready` if present, drain `_outbox` into `_streamSink` in FIFO order, then fire `_readyController.add(null)` so the domain layer's `flushBuffer()` runs at the correct moment.
- `emit(sample)`: open the stream as today when `_streamSink == null` (still guard on `_isGrpcConnected`). Then: if `_isReady` → `_streamSink!.add(proto)`; else → `_outbox.add(proto)`. Nothing reaches the sink before `ready`.
- Fallback net: in `_openStream`, start a `Timer(_readyTimeout)` (e.g. 5 s). If it fires while `!_isReady`, log a warning (`logPrint('[ModuleInstructionStream] readiness timeout — flushing without server ready')`), force `_isReady = true`, drain the outbox, fire `_readyController`. Cancel the timer on `ready` and on stream close/disconnect. This prevents a permanent deadlock against an un-upgraded server (degrades to today's behavior); server-first deploy remains the contract.

### Reconcile the domain layer — `lib/BreathModule/Core/BreathModuleInstructionStream.dart`

- `readyEvents` now fires on **server** ready, so `flushBuffer()` drains the domain `_buffer` at the right time — no signature change needed there.
- **FIFO across the two buffers:** the domain `_buffer` holds the reconnect/rate backlog; the transport `_outbox` holds samples emitted after open but before `ready`. On `ready`, ensure phase order is preserved — drain so the older backlog precedes newer outbox entries (run `flushBuffer` into the outbox while still gating, then drain the outbox once), or unify into a single ordered queue. The implementer must verify no phase reordering on reconnect.

### Cleanup

Remove the throwaway `[probe]` lines (note-44 verification) added across `ModuleInstructionStream`, `BreathModuleInstructionStream`, `BreathModuleStateChannel`, and `ModuleStateChannel` in the same change.

### Guards

- Logging only through `logPrint` (project facade).
- Do NOT implement eager-open — the handshake subsumes it; opening tunnels at connect is explicitly out of scope.
- Do NOT touch the biometric client here (note 115).
- Deploy AFTER mind_api note 48; the fallback timeout is a safety net, not a license to deploy mobile-first.

### Verify

Cold session: the `rest` row appears in `session_stream_samples` (server-side query by `moduleSessionId`) and the first ack carries the expected `receivedCount` including `rest`. Reconnect mid-session (toggle transport): every phase across the gap is persisted, none dropped, order preserved.

## Open Questions

- None blocking. The dual-buffer FIFO reconciliation is an implementation detail flagged above, not a design gap.
