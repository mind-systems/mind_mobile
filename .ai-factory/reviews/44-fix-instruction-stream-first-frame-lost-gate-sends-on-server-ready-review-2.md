# Code Review (round 2): Fix instruction-stream first frame lost — gate sends on server `ready`

**Plan:** `44-fix-instruction-stream-first-frame-lost-gate-sends-on-server-ready.md`
**Diff scope reviewed:** `git diff HEAD` + `git status` (re-read all changed files in full)
**Code files changed:** `lib/Core/Grpc/ModuleInstructionStream.dart`, `lib/BreathModule/Core/BreathModuleInstructionStream.dart`, `proto/module_instruction_stream.proto`, `lib/Core/Grpc/generated/module_instruction_stream.pb*.dart` (regen)
**Risk Level:** 🟢 Low — clean. Round-1 findings resolved; no new issues.

## What changed since review-1

The implementation was revised and now resolves every round-1 observation:

- **Round-1 #1 (dead `readyEvents` API) — RESOLVED.** `_readyController` and the `readyEvents` getter are removed entirely; `dispose` no longer closes them. `_becomeReady` no longer adds to a controller. Confirmed zero remaining references to `readyEvents`/`_readyController` in `lib/`.
- **Round-1 #2 (single-slot hook overwrite) — ADDRESSED.** `setReadyDrainHook` now carries `// Single consumer — last registration wins.`
- **Round-1 #4 (unrelated `ModuleStateChannel` cosmetic change) — RESOLVED.** `ModuleStateChannel.dart` is no longer in the diff (`git status` clean for it).
- **Round-1 #3 (5 s degradation latency vs un-upgraded server)** is inherent to the fallback design and documented; not a code defect.

## Verification performed

- **`flutter analyze`** on both changed source files: *No issues found.*
- **No `[probe]` lines** remain anywhere in `lib/`.
- **Generated stub** correct: `StreamResponse_Event.ready`, `r.ready`, and `StreamReady.maxSamplesPerSecond` / `.timestamp` all present and used correctly.
- **`_streamSink!` null-safety invariant holds.** The only path that nulls `_streamSink` is the `disconnected` branch, which in the same synchronous callback also sets `_isReady = false` and cancels `_readyTimer`. Therefore:
  - In `emit`, the direct path `_streamSink!.add(proto)` runs only when `_isReady == true`, which (given the above) implies the sink has not been nulled. Safe.
  - `_drainOutbox`'s `_streamSink!.add(s)` runs only from `_becomeReady`, reached either from the `ready` branch (inside the live subscription → sink non-null) or `_onReadyTimeout` (timer is cancelled on every teardown path, so it cannot fire against a nulled sink). Safe.
- **First-frame fix** holds: the first emitted sample lands in `_outbox` (gate closed) and is only flushed after server `ready`.
- **FIFO across the domain `_buffer` and transport `_outbox`** holds: `_becomeReady` invokes the drain hook (`flushBuffer`) while `_isReady` is still `false`, so domain-buffered samples enter `_outbox` before `_drainOutbox` timestamp-sorts and sends. Traced a mid-session reconnect: outage-backlog phases (domain `_buffer`) carry older timestamps than the reopen-trigger sample (`_outbox`), so the ascending sort yields correct order.
- **Re-entrancy / idempotency safe:** `flushBuffer → emit` during `_becomeReady` cannot re-open the stream (sink non-null) or reach the sink (gate still closed); `_buffer.flush()` clears as it returns (no duplication); a timeout-then-late-`ready` double `_becomeReady` no-ops on the second pass.
- **Synthetic rate-hint ack** (`sessionId:''`, zero counts) is inert for the sole `acks` consumer `_onDataAck`, which reads only `maxSamplesPerSecond`; delivery is on a microtask, after the synchronous `ready` handling, so no re-entrancy.
- **Single instance** confirmed in `App.dart` — one `ModuleInstructionStream`, one `BreathModuleInstructionStream`; no second hook registrant.

## Note (pre-existing, not a finding against this change)

A sample emitted in the narrow window between `onError`/`onDone` and the `disconnected` state propagating takes the gated path into `_outbox` and is then cleared by the `disconnected` branch (it is not retained in the domain `_buffer` because it went through the `_emit` direct path). This at-most-once edge also existed before the change (the original code added such a sample to a soon-closed, unlistened sink, where it was likewise discarded). Behavior is equivalent and out of scope for this fix.

## Conclusion

The readiness-gate implementation is correct, the round-1 findings are resolved, the analyzer is clean, and I found no correctness, security, or runtime-breakage issues in this revision.

REVIEW_PASS
