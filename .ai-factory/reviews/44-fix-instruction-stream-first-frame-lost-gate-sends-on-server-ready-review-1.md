# Code Review: Fix instruction-stream first frame lost — gate sends on server `ready`

**Plan:** `44-fix-instruction-stream-first-frame-lost-gate-sends-on-server-ready.md`
**Reviewed:** committed change `ef2f5c4` (`git diff HEAD~1 HEAD`); working tree clean.
**Code files changed:** `lib/Core/Grpc/ModuleInstructionStream.dart`, `lib/BreathModule/Core/BreathModuleInstructionStream.dart`, `proto/module_instruction_stream.proto`, `lib/Core/Grpc/generated/module_instruction_stream.pb*.dart` (regen)
**Risk Level:** 🟢 Low — clean implementation; no findings.

## Summary

The committed change implements the readiness gate exactly per the plan: a transport-level `_isReady` flag + a single `_outbox`, a synchronous `_readyDrainHook`, a timestamp-sorted single drain, a 5 s fallback timer, and the rate hint surfaced through the existing `acks` path. I read both source files in full and traced the cold-start, mid-session-reconnect, timeout-fallback, and double-`_becomeReady` paths. No correctness, security, or runtime-breakage issues found.

## Verified correct

- **First-frame fix.** On a fresh open, `emit` routes the first sample to `_outbox` (gate closed) and it is sent only after server `ready` → `_drainOutbox`. The original `_streamSink!.add(...)`-before-subscribe race is eliminated. `_openStream` no longer signals "local open".
- **FIFO across the two buffers.** `_becomeReady` calls `_readyDrainHook` (domain `flushBuffer`) while `_isReady` is still `false`, so domain-buffered samples enter `_outbox` before `_drainOutbox` sorts ascending by `StreamSample.timestamp`. Traced an interleaved case (some samples through the rate gate into `_outbox`, some rate-limited into the domain `_buffer`) and a mid-session reconnect (outage backlog carries older timestamps than the reopen-trigger sample) — the sort reconstructs true emission order in both.
- **`_streamSink!` null-safety invariant holds.** The only path that nulls `_streamSink` is the `disconnected` branch, which in the same synchronous callback also clears `_isReady` and cancels `_readyTimer`. Hence: `emit`'s direct path (`_isReady == true`) implies a non-null sink; and `_drainOutbox` runs only from `_becomeReady`, reached from the `ready` branch (live subscription → sink non-null) or `_onReadyTimeout` (timer cancelled on every teardown, so it cannot fire against a nulled sink).
- **Re-entrancy / idempotency.** `flushBuffer → emit` during `_becomeReady` cannot re-open the stream (sink non-null) nor reach the sink (gate still closed); `_buffer.flush()` clears as it returns (no duplication); a timeout-then-late-`ready` double `_becomeReady` no-ops on the second pass.
- **Rate hint.** The synthetic `InstructionAck(sessionId:'', receivedCount:0, droppedCount:0, …)` is inert for the sole `acks` consumer `_onDataAck`, which reads only `maxSamplesPerSecond`; broadcast delivery is on a microtask, after the synchronous `ready` handling — no re-entrancy.
- **Gate re-arm.** `_isReady=false` + `_outbox.clear()` + `_readyTimer?.cancel()` at the top of `_openStream` and on `disconnected`/`onError`/`onDone` cover cold start, reconnect, and teardown. The domain `_buffer` is intentionally not cleared on disconnect, preserving the reconnect backlog.
- **Graceful degradation.** Against an un-upgraded server (no `ready`), `_onReadyTimeout` flushes after 5 s with a `logPrint` warning instead of deadlocking. (Tradeoff: first send is held up to 5 s; documented and acceptable — deploy is server-first.)
- **Hygiene.** `_readyController`/`readyEvents` removed entirely (no dead API); `setReadyDrainHook` documents "single consumer — last registration wins"; `App.dart` constructs exactly one `ModuleInstructionStream` and one `BreathModuleInstructionStream`, so no second hook registrant. `flutter analyze` on both files: *No issues found.* No `[probe]` lines remain in `lib/`. Generated stub exposes `StreamResponse_Event.ready`, `r.ready`, and `StreamReady.maxSamplesPerSecond`/`.timestamp`, all used correctly.

## Note (pre-existing, not a finding against this change)

A sample emitted in the narrow window between `onError`/`onDone` and the `disconnected` state propagating takes the gated path into `_outbox` and is then cleared by the `disconnected` branch (it is not retained in the domain `_buffer`, having gone through the `_emit` direct path). This at-most-once edge also existed before the change — the original code added such a sample to a soon-closed, unlistened sink, where it was likewise discarded. Behavior is equivalent and out of scope for this fix.

## Conclusion

The readiness-gate implementation is correct and resolves the dropped-first-frame bug, including the FIFO-ordering and rate-hint concerns. No correctness, security, or runtime issues.

REVIEW_PASS
