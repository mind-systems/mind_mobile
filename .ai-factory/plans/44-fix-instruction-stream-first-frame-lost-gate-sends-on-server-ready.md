# Plan: Fix instruction-stream first frame lost — gate sends on server `ready`

## Context
The first instruction frame (`rest`) is dropped on every freshly-opened instruction tunnel because the client adds samples to the sink before the server's post-auth `request.subscribe()` runs. Move the race guard from *local stream open* to a server-driven `ready` handshake so no sample reaches the sink before the server is subscribed — covering both cold start and mid-session reconnect.

## Design decisions (resolving plan-review-1)

The review flagged that note-114's proposed mechanism — fire `_readyController.add(null)` and let the `readyEvents` listener flush the domain buffer — **cannot** preserve phase order, because `StreamController.add()` dispatches listeners on a microtask. By the time the domain `flushBuffer()` runs, the gate is already open and the outbox already drained, so the (older) domain backlog lands *after* the (newer) outbox. The review also showed the two buffers interleave in time (a rate-limited sample lands in the domain `_buffer` while the previous sample already went to `_outbox`), so "domain-before-outbox" draining is wrong regardless of timing. This plan therefore deviates from note-114's exact wiring with two concrete primitives:

1. **Synchronous drain hook (not `readyEvents`-driven flush).** The transport exposes `setReadyDrainHook(void Function() hook)`; the domain registers `flushBuffer`. On `ready`, the transport calls the hook **synchronously while the gate is still closed** (`_isReady == false`), so the domain backlog is pushed into the single transport `_outbox` *before* the drain — no microtask, no reordering window.
2. **Single timestamp-sorted drain.** There is exactly one ordered buffer to drain (`_outbox`). The drain sorts by the `StreamSample.timestamp` field (ascending) before writing to the sink, so true emission order is reconstructed even when the domain `_buffer` and `_outbox` interleaved in time. Ties on equal timestamps are acceptable.
3. **Rate hint via the existing `acks` path.** `readyEvents` is `Stream<void>` and cannot carry the rate. On `ready`, when `r.ready.maxSamplesPerSecond > 0`, emit a synthetic `InstructionAck(receivedCount: 0, droppedCount: 0, maxSamplesPerSecond: r.ready.maxSamplesPerSecond, …)` through the existing `_ackController`. `_onDataAck` (the sole `acks` consumer) reads only `maxSamplesPerSecond`, so zero counts are harmless and the rate limiter is seeded before the first send. Lowest-churn, preserves the ack-driven update path.

Verified fan-out before designing: `readyEvents` has exactly one consumer (`BreathModuleInstructionStream:21`) and `acks` has exactly one consumer (`_onDataAck`, `BreathModuleInstructionStream:22`) — so repointing both is safe.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Proto contract & codegen

- [x] **Task 1: Copy updated proto and regenerate Dart stubs**
  Files: `proto/module_instruction_stream.proto`, `lib/Core/Grpc/generated/module_instruction_stream.pb*.dart`
  The source of truth `mind_api/proto/module_instruction_stream.proto` already carries the new `StreamReady` message (`int32 max_samples_per_second = 1; int64 timestamp = 2;`) and the `StreamReady ready = 3;` arm inside `StreamResponse`'s `oneof event`; the mobile copy does **not** yet. Copy `mind_api/proto/module_instruction_stream.proto` over `mind_mobile/proto/module_instruction_stream.proto` (explicit copy, no symlink — per proto-ownership rules). Then run `./scripts/gen_proto.sh`. Note the script `rm -rf`s the whole `OUT_DIR` and regenerates **all** `.proto` files; that is a no-op for the unchanged ones. Verify the regenerated `module_instruction_stream.pb.dart` now exposes `StreamResponse_Event.ready`, an `r.ready` accessor, and the `StreamReady` type with a `maxSamplesPerSecond` accessor (mirrors the existing `StreamAck.maxSamplesPerSecond`). Do NOT modify any other `.proto` file.

### Phase 2: Transport-layer readiness gate

- [x] **Task 2: Add `_isReady` + single outbox + synchronous drain hook to `ModuleInstructionStream`** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleInstructionStream.dart`
  Move the authoritative race guard into the transport layer:
  - Add fields: `bool _isReady = false;`, `final List<StreamSample> _outbox = [];`, `Timer? _readyTimer;`, `void Function()? _readyDrainHook;`, and a `static const _readyTimeout = Duration(seconds: 5);`.
  - Add `void setReadyDrainHook(void Function() hook) => _readyDrainHook = hook;` — the domain registers `flushBuffer` here (the callback is a plain `void Function()`, so no domain type leaks into the transport layer; dependency direction stays domain→transport, same as the existing stream subscriptions).
  - Add a private `void _drainOutbox()`: stable-ish sort `_outbox` by the proto `timestamp` field ascending (`_outbox.sort((a, b) => a.timestamp.compareTo(b.timestamp));`), then `for (final s in _outbox) _streamSink!.add(s);`, then `_outbox.clear();`.
  - Add a private `void _becomeReady()` shared by the `ready` branch and the timeout: call `_readyDrainHook?.call()` **while `_isReady` is still false** (domain `flushBuffer` emits its backlog into the still-gated `_outbox`), then set `_isReady = true`, call `_drainOutbox()`, then `_readyController.add(null)`. `readyEvents` is retained purely as a post-drain notification (it has no required consumer after this change; the domain flush is driven by the hook, not by `readyEvents`).
  - `_openStream()`: start with `_readyTimer?.cancel();` (defensive — avoid a leaked timer from a prior cycle firing into the new one), then `_isReady = false`, `_outbox.clear()` (re-arms the gate for cold start AND reconnect). Create the sink and subscribe as today. **Remove** the trailing `_readyController.add(null)` call — readiness is no longer "local open". Start `_readyTimer = Timer(_readyTimeout, _onReadyTimeout)`.
  - `_onReadyTimeout()`: if `_isReady` already, return. Else `logPrint('[ModuleInstructionStream] readiness timeout — flushing without server ready')` and call `_becomeReady()`. Degrades gracefully against an un-upgraded server instead of deadlocking.
  - In the response listener `switch (r.whichEvent())`, add `case StreamResponse_Event.ready:` → `_readyTimer?.cancel();` then, if `r.ready.maxSamplesPerSecond > 0`, push the rate hint to the domain through the existing `acks` path: `_ackController.add(InstructionAck(sessionId: '', receivedCount: 0, droppedCount: 0, maxSamplesPerSecond: r.ready.maxSamplesPerSecond, timestamp: r.ready.timestamp.toInt()));` (zero counts are harmless — `_onDataAck` reads only `maxSamplesPerSecond`). Then call `_becomeReady()`.
  - `emit(sample)`: keep the existing open-on-null-sink behavior (still guard on `_isGrpcConnected`; still set `_streamRequested = true` and call `_openStream()`). After the sink exists, route the proto by gate state: `if (_isReady) _streamSink!.add(proto); else _outbox.add(proto);`. Nothing reaches the sink before `ready`.
  - Reset points: cancel `_readyTimer`, set `_isReady = false`, and `_outbox.clear()` on the `disconnected` connection-state branch (where `_streamSub`/`_streamSink` are torn down), in `onError`, in `onDone`, and in `dispose()`. (`_openStream()` already re-arms at the top for the `connected`→reopen path.)
  - Logging only via `logPrint`. Do NOT implement eager-open.

### Phase 3: Domain-layer reconciliation

- [x] **Task 3: Register the drain hook and stop using `readyEvents` for flushing in `BreathModuleInstructionStream`** (depends on Task 2)
  Files: `lib/BreathModule/Core/BreathModuleInstructionStream.dart`
  - In the constructor, **replace** `_instructionReadySub = _instructionStream.readyEvents.listen((_) => flushBuffer());` with `_instructionStream.setReadyDrainHook(flushBuffer);`. The synchronous hook now drives the flush at exactly the right moment (gate still closed), so `flushBuffer() → _instructionStream.emit(...)` routes the domain backlog into the still-gated `_outbox` ahead of the single sorted drain — preserving global timestamp order across both buffers. Remove the now-unused `_instructionReadySub` field and its `cancel()` in `dispose()`.
  - Leave `_dataAckSub = _instructionStream.acks.listen(_onDataAck);` unchanged — it now also receives the synthetic ready-rate ack and seeds `_maxSamplesPerSecond` before the first send, in addition to the normal ack-driven updates. No further change needed in `_onDataAck`.
  - `flushBuffer()` itself is unchanged in shape (drain `_buffer`, re-emit each via `_instructionStream.emit`); its samples now flow through the transport gate/outbox rather than straight to the sink.

### Phase 4: Cleanup

- [x] **Task 4: Remove all `[probe]` lines added for note-44 verification** (depends on Task 3)
  Files: `lib/Core/Grpc/ModuleInstructionStream.dart`, `lib/BreathModule/Core/BreathModuleInstructionStream.dart`, `lib/Core/Grpc/ModuleStateChannel.dart`, `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  Remove every `logPrint('[probe] ...'); // note 44 — remove after reading result` line across these four files (16 lines total). Where a probe line sits beside a genuine log (e.g. the real `logPrint('[ModuleInstructionStream] not connected, dropping sample')` at `ModuleInstructionStream.dart:74`, adjacent to the probe at line 73), keep the genuine line and strip only the `[probe]` one. After removal, confirm no `[probe]` substring remains anywhere in `lib/`.

## Verify
- Cold session: the `rest` row appears in `session_stream_samples` (server-side query by `moduleSessionId`) and the first ack carries `receivedCount` including `rest`.
- Reconnect mid-session (toggle transport): every phase across the gap is persisted, none dropped, order preserved (timestamp-ascending).
- Un-upgraded server simulation (server never sends `ready`): after ~5 s the timeout warning logs once and samples flush — no deadlock. Deploy remains server-first (mind_api note 48 first); the timeout is a safety net, not a license to deploy mobile-first.
