# Code Review 3: Collapse `BreathModuleInstructionStream` to a thin mapper

**Scope:** code changes only (`git diff HEAD`).
- `lib/BreathModule/Core/BreathModuleInstructionStream.dart` (modified)
- `lib/Core/Grpc/ModuleInstructionStream.dart` (modified)
- `lib/Core/Grpc/InstructionAck.dart`, `lib/Core/Grpc/InstructionBuffer.dart`, `test/Core/Grpc/instruction_buffer_test.dart` (deleted)

## Summary

The refactor is correct, complete, and now internally consistent with its spec and plan. `BreathModuleInstructionStream` is reduced to a pure map→`emit` mapper: it retains only the `_instructionStream` field, the constructor, and `sendSample(sessionId, phase, durationMs, timestampMs)`, with the wire contract (`moduleId='breath'`, `instructionType='breath_phase'`, `data={phase,durationMs}`, `timestamp=timestampMs`) preserved. The rate-limit cap is relocated into `ModuleInstructionStream`, reading `maxSamplesPerSecond` directly from `ack`/`ready`, applying the min-interval gate on the live-send path, and resetting `_lastSendTime` on both disconnect and reopen. All orphaned plumbing (`acks`/`_ackController`, `setReadyDrainHook`/`_readyDrainHook`, the `isGrpcConnected` getter, `InstructionAck`, `InstructionBuffer` + its test) is removed.

## Resolution of prior-review findings

- **Review-1 #1 / Review-2 #1 (over-cap behavior + spec contradiction):** resolved. Over-cap samples are explicitly dropped and now logged — `logPrint('[ModuleInstructionStream] over-cap, dropping sample')` (lines 84–91), matching the observability of the sibling "not connected, dropping sample" path. Spec note 117 was rewritten (Guards: "Over-cap samples are dropped (not deferred) … inert for breath") and the plan's design-decision/Task 2 text updated to match. Code, plan, and spec now agree; the earlier "not silently dropped" contradiction is gone.
- **Review-1 #2 (`_lastSendTime` not reset):** resolved. `_lastSendTime = null` is set in the `disconnected` handler (line 61) and at the top of `_openStream` (line 112), so the rate window starts fresh per connection and no stale timestamp survives a reconnect.

## Verification performed

- Read both modified files in full and reviewed the deletions against their prior contents.
- Confirmed (grep, whole repo) no remaining references to `acks`, `setReadyDrainHook`, `_readyDrainHook`, the `isGrpcConnected` getter, `InstructionAck`, `InstructionBuffer`, `flushBuffer`, or `readyEvents`. The `isConnected` matches are all `BciDataState.isConnected`, an unrelated symbol.
- `sendSample` callers (`BreathModuleStateChannel:104,111`), the test fake (`_FakeInstructionStream`), and `App.dart` wiring all match the preserved 4-arg signature; nothing calls `breathInstructionStream.dispose()`.
- Re-checked the runtime-sensitive paths: `1000 ~/ _maxSamplesPerSecond` cannot divide by zero (defaults to 10, only overwritten when `> 0`); first-`rest` delivery is intact (pre-ready samples buffered in `_outbox`, drained FIFO on `ready`, and the first live send is ungated because `_lastSendTime` starts null); `_pendingInstruction` parking is untouched.

## Non-blocking observation

- `ModuleInstructionStream.isConnected` getter (line 39) is unused dead code, pre-existing and explicitly left by the plan; not introduced by this change and harmless. No action required.

No bugs, security issues, or correctness problems found in the code changes. All findings from prior reviews are addressed.

REVIEW_PASS
