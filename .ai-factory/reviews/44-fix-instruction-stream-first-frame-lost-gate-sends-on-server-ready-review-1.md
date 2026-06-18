# Code Review: Fix instruction-stream first frame lost — gate sends on server `ready`

**Plan:** `44-fix-instruction-stream-first-frame-lost-gate-sends-on-server-ready.md`
**Diff scope reviewed:** `git diff HEAD` + `git status`
**Files changed (code):** `lib/Core/Grpc/ModuleInstructionStream.dart`, `lib/BreathModule/Core/BreathModuleInstructionStream.dart`, `lib/Core/Grpc/ModuleStateChannel.dart`, `proto/module_instruction_stream.proto`, `lib/Core/Grpc/generated/module_instruction_stream.pb*.dart` (regen)
**Risk Level:** 🟢 Low — core fix is correct; only minor/non-blocking observations.

## Summary

The change implements the readiness gate exactly as the (already plan-reviewed) plan specifies: a transport-level `_isReady` flag + single `_outbox`, a synchronous `_readyDrainHook`, a timestamp-sorted single drain, a 5 s fallback timer, and the rate hint surfaced through the existing `acks` path. I traced the cold-start, reconnect-interleave, timeout-fallback, and double-`_becomeReady` paths and found **no correctness, security, or runtime-breakage bugs**. The proto regen is correct (`StreamResponse_Event.ready`, `r.ready`, `StreamReady.maxSamplesPerSecond`/`timestamp` all present). All `[probe]` lines are gone from `lib/`.

## Verified correct

- **First-frame fix.** On a fresh open, `emit` routes the first sample to `_outbox` (gate closed), and it is only sent after `ready` → drain. The original `_streamSink!.add(...)`-before-subscribe race is eliminated.
- **FIFO across the two buffers.** `_becomeReady` calls `_readyDrainHook` (domain `flushBuffer`) **while `_isReady` is still false**, so domain-buffered samples land in `_outbox` before the drain; `_drainOutbox` then sorts by `StreamSample.timestamp` ascending. Traced an interleaved case (some samples in `_outbox` via the rate gate, some in the domain `_buffer` via rate-limit) — the timestamp sort reconstructs true emission order. Resolves plan-review-1 issues #1 and #2.
- **Re-entrancy safe.** `flushBuffer` → `emit` during `_becomeReady` cannot re-open the stream (`_streamSink != null`) and cannot reach the sink (`_isReady` still false). No duplication: `_buffer.flush()` clears as it returns.
- **Gate re-arm on reconnect/cold start.** `_isReady=false` + `_outbox.clear()` at the top of `_openStream` and on the `disconnected`/`onError`/`onDone` paths; `_readyTimer?.cancel()` defensively at the top of `_openStream` prevents a leaked timer from a prior cycle. The domain `_buffer` is intentionally **not** cleared on disconnect, preserving the reconnect backlog — correct.
- **`_drainOutbox`'s `_streamSink!` is safe.** The only way `_streamSink` becomes null is the `disconnected` branch, which cancels `_readyTimer` in the same synchronous callback — so `_onReadyTimeout` cannot fire against a null sink. The `ready` branch runs inside the live stream subscription, so the sink is non-null there.
- **Double `_becomeReady` (timeout then late `ready`) is idempotent** — second pass no-ops (empty buffer/outbox, `_isReady` already true). Harmless.
- **Rate-hint channel.** Synthetic `InstructionAck(sessionId:'', receivedCount:0, droppedCount:0, …)` is inert for the sole `acks` consumer `_onDataAck`, which reads only `maxSamplesPerSecond`. Confirmed `acks` and `readyEvents` each had exactly one consumer.
- **Single instance.** `App.dart` creates exactly one `ModuleInstructionStream` and one `BreathModuleInstructionStream`; no second `setReadyDrainHook` registrant exists. Meditation is lifecycle-only and the biometric stream (note 115) is a separate instance.

## Findings (all minor / non-blocking)

### 1. `readyEvents` / `_readyController` is now dead public API
After moving the flush trigger to `setReadyDrainHook`, nothing subscribes to `readyEvents` anywhere in `lib/` (the former sole consumer in `BreathModuleInstructionStream` was removed). `_becomeReady` still calls `_readyController.add(null)` and `dispose` still closes it, but there are no listeners. Harmless (broadcast controller drops events with no subscribers), but it is now unused surface area. Consider either removing `_readyController`/`readyEvents` entirely or leaving a one-line comment that it is retained as a post-drain notification hook for future consumers. Not blocking.

### 2. Single-slot `_readyDrainHook` silently overwrites on a second registrant
`setReadyDrainHook` stores one `void Function()?`; a hypothetical second consumer would silently replace the first's flush. Correct for the current single-consumer wiring, but fragile if the instruction stream is ever shared. A short doc comment ("single consumer; last registration wins") would de-risk future reuse. Informational.

### 3. Un-upgraded-server degradation holds the first frame for the full 5 s
By design, against a server that never sends `ready`, samples buffer in `_outbox` until `_onReadyTimeout` fires — even if the server is already `ack`ing. This adds ~5 s latency to the first send for an un-upgraded backend. This is the documented graceful-degradation tradeoff (deploy is server-first), so acceptable; flagging only so it is a conscious expectation, not a surprise. Not a bug.

### 4. Unrelated cosmetic change bundled in `ModuleStateChannel.dart`
The only net diff vs `HEAD` in `ModuleStateChannel.dart` is wrapping an early `return` in braces (`if (...) { return; }`) — behavior-identical, and unrelated to the readiness gate. (The note-44 `[probe]` lines this task was meant to strip were never committed to `HEAD`, so their removal is invisible in `git diff HEAD`; `grep` confirms none remain in `lib/`.) Harmless minor scope-creep. Optional to drop.

## Conclusion

The core gating strategy is implemented correctly and resolves the dropped-first-frame bug, including the FIFO-ordering concerns raised in plan-review-1. The four findings above are all minor cleanups/observations with no correctness, security, or runtime impact — none block merge.
