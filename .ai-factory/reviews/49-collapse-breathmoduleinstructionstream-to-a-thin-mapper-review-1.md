# Code Review: Collapse `BreathModuleInstructionStream` to a thin mapper

**Scope reviewed:** code changes only (`git diff HEAD`).
- `lib/BreathModule/Core/BreathModuleInstructionStream.dart` (modified)
- `lib/Core/Grpc/ModuleInstructionStream.dart` (modified)
- `lib/Core/Grpc/InstructionAck.dart` (deleted)
- `lib/Core/Grpc/InstructionBuffer.dart` (deleted)
- `test/Core/Grpc/instruction_buffer_test.dart` (deleted)

Plan/roadmap/json files are not reviewed for runtime correctness.

## Summary

The refactor is clean and matches the plan. `BreathModuleInstructionStream` is now a pure map→`emit` with no buffer, subscriptions, or `dispose()`. The constructor signature, the `sendSample(sessionId, phase, durationMs, timestampMs)` signature, and the wire contract (`moduleId='breath'`, `instructionType='breath_phase'`, `data={phase,durationMs}`, `timestamp=timestampMs`) are all preserved, so `breath_module_state_channel_test.dart` (`_FakeInstructionStream implements BreathModuleInstructionStream`) and `BreathModuleStateChannel._pendingInstruction` parking are untouched. Orphan removal is complete: a full-codebase grep confirms **no** dangling references to `acks`, `setReadyDrainHook`, `_readyDrainHook`, the `isGrpcConnected` getter, `InstructionAck`, `InstructionBuffer`, or `flushBuffer`. The only remaining `_isGrpcConnected` matches are the private field, still legitimately used by `emit`. `App.dart` wiring is unaffected (constructor unchanged; nothing called `breathInstructionStream.dispose()`). `1000 ~/ _maxSamplesPerSecond` cannot divide by zero — the field defaults to 10 and is only overwritten when `> 0`.

One substantive finding below, plus two minor notes.

## Findings

### 1. (Low–Medium) Rate-limited samples routed to `_outbox` are never drained in steady state — the cap now effectively *drops* over-cap samples rather than *delaying* them

`ModuleInstructionStream.emit` (lines 83–94) routes a too-soon sample into `_outbox`:

```dart
if (_isReady) {
  final minIntervalMs = 1000 ~/ _maxSamplesPerSecond;
  if (_lastSendTime != null &&
      DateTime.now().difference(_lastSendTime!).inMilliseconds < minIntervalMs) {
    _outbox.add(proto);            // <-- deferred here
  } else {
    _streamSink!.add(proto);
    _lastSendTime = DateTime.now();
  }
} else {
  _outbox.add(proto);
}
```

`_outbox` is drained **only** by `_drainOutbox()`, which runs **only** from `_becomeReady()` — i.e. on a server `ready` event or the 5 s readiness-timeout fallback. After the stream is ready, no further `ready` arrives in steady state, so a sample deferred here sits in `_outbox` indefinitely. The next time the outbox *would* drain is a reconnect — but both the `disconnected` handler (line 61) and `_openStream` (line 109) call `_outbox.clear()` *before* the new stream becomes ready, so the deferred sample is discarded, not delivered.

This diverges from the plan's stated goal ("preserving the original hold-don't-drop semantics"). In the old code, an over-cap sample was held in the persistent domain `InstructionBuffer` (capacity 500, **not** cleared on disconnect) and re-emitted on the next `ready` via the `setReadyDrainHook(flushBuffer)` path — so it was eventually delivered. The new code drops it on reconnect and never delivers it in steady state. Net effect: the relocated cap *drops* over-cap samples instead of *delaying* them.

**Practical impact for the only current consumer (breath): negligible.** Breath phase changes are seconds apart against a 100 ms (10/s) minimum interval, so the rate branch is effectively never taken — the plan correctly calls the gate "inert." The only realistic trigger is a genuine phase change landing <100 ms after a `_flushPending` send near a phase boundary, which is rare, and the dropped sample is a single redundant phase instruction.

**Why it still matters:** (a) the plan claims a delivery guarantee that the implementation does not provide, which will mislead a future reader; (b) `ModuleInstructionStream` is positioned (Phase 38 rationale) as a generic transport that "future modules reusing the streams get delivery guarantees for free" — a higher-frequency consumer would silently accumulate undeliverable samples in `_outbox` (unbounded growth, since unlike the old buffer the outbox has no capacity cap) until a reconnect clears them.

**Recommendation** (pick one):
- *Document-and-accept:* update the plan/comment to state that over-cap samples are dropped (acceptable because the cap never trips for breath), and note the unbounded-`_outbox` caveat for future high-rate consumers. Lowest effort, honest.
- *Make it truly "delay":* schedule a one-shot flush of the deferred sample after `minIntervalMs` (e.g. a short timer that writes the buffered proto to the sink when ready), so the cap throttles rather than drops. More faithful to the original intent, more code.

### 2. (Nit) `_lastSendTime` is not reset on disconnect/reopen

`_lastSendTime` retains its pre-disconnect value across a reconnect. This is harmless today: a reconnect takes far longer than `minIntervalMs`, so the first post-reconnect `emit` always passes the interval check and sends immediately. Worth a one-line reset alongside the other reconnect cleanup (lines 59–61 / 107–110) only if you want the rate window to start fresh per connection. Not required.

### 3. (Nit / pre-existing) `isConnected` getter (line 39) is now unused

The plan deliberately left it. It is a pre-existing orphan (no consumer found in the codebase), unrelated to this change. Mentioned only for completeness; no action needed.

## Verification performed
- Read both modified files in full and the deleted files' prior contents (from conversation history).
- Grepped the whole repo for every removed public symbol — no dangling references.
- Confirmed the state-channel test fake and `_pendingInstruction` path are untouched by the diff.
- Confirmed no division-by-zero in the relocated cap and no compile-time breakage in `App.dart` wiring.

The single substantive finding (#1) is a behavioral divergence from the plan's stated semantics, low impact for the current breath consumer but a latent issue for the generic transport. Worth a decision before merge.
