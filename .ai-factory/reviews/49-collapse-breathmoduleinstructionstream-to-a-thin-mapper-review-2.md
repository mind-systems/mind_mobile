# Code Review 2: Collapse `BreathModuleInstructionStream` to a thin mapper

**Scope:** code changes only (`git diff HEAD`).
- `lib/BreathModule/Core/BreathModuleInstructionStream.dart` (modified)
- `lib/Core/Grpc/ModuleInstructionStream.dart` (modified)
- `lib/Core/Grpc/InstructionAck.dart`, `lib/Core/Grpc/InstructionBuffer.dart`, `test/Core/Grpc/instruction_buffer_test.dart` (deleted)

## Summary

The refactor is correct and the orphan removal is complete. `BreathModuleInstructionStream` is now a pure map→`emit` with the `sendSample(sessionId, phase, durationMs, timestampMs)` signature and the wire contract (`moduleId='breath'`, `instructionType='breath_phase'`, `data={phase,durationMs}`, `timestamp=timestampMs`) preserved, so `breath_module_state_channel_test.dart` and `BreathModuleStateChannel._pendingInstruction` parking are untouched. A whole-repo grep confirms no remaining references to `acks`, `setReadyDrainHook`, `_readyDrainHook`, the `isGrpcConnected` getter, `InstructionAck`, `InstructionBuffer`, or `flushBuffer` (the `isConnected` hits are all `BciDataState.isConnected`, an unrelated symbol). `App.dart` wiring is intact and nothing calls `breathInstructionStream.dispose()`. `1000 ~/ _maxSamplesPerSecond` cannot divide by zero (defaults to 10, only overwritten when `> 0`). First-`rest` delivery is intact: pre-ready samples go to `_outbox` and drain on `ready`, and since `_lastSendTime` starts null the first live send is never gated.

Since review-1, the over-cap branch was changed to **drop** the sample (lines 88–92) instead of buffering to `_outbox`, and `_lastSendTime` is now reset on disconnect (line 61) and reopen (line 112) — review-1's nit #2 is resolved, and the new drop path avoids the never-drained `_outbox` accumulation that review-1 flagged. One finding remains, below.

## Findings

### 1. (Low) Over-cap samples are dropped *silently*, contradicting the spec's explicit "not silently dropped" guard and the plan's own design text

`emit` now discards an over-cap sample with a bare `return` and no log (lines 88–92):

```dart
if (_lastSendTime != null &&
    DateTime.now().difference(_lastSendTime!).inMilliseconds < minIntervalMs) {
  // Over-cap: drop. ...
  return;
}
```

This is a reasonable, clean cap behavior and is practically inert for breath (phase changes are seconds apart vs. the 100 ms / 10-per-second cap). But it diverges from two written sources that should be reconciled before close:

- **Spec note 117** states under Details: *"Behavior must be preserved (cap enforced, **not silently dropped**)"* and under Guards: *"Preserve rate-limit behavior wherever it lands — do not drop the cap."* The implementation now silently drops.
- **The plan itself** (design-decision bullet, line 14; Task 2, line 36) still says to *"route the proto into `_outbox` (held, drained on the next `ready`) instead of dropping it"* — the opposite of what shipped. The checked-off task text no longer matches the code.

Note that review-1 established the `_outbox` route also fails to deliver in steady state (it only drains on `ready`, and reconnect clears it first), so "drop" is arguably the more honest implementation — I am not asking to revert to the outbox approach. The finding is the **unreconciled contradiction**: the code does one thing while the spec guard and the plan assert another.

Additionally, the drop is *truly* silent, unlike the sibling drop path in the same method which logs (`logPrint('[ModuleInstructionStream] not connected, dropping sample')`, line 78). For observability parity, a dropped over-cap sample is the kind of event worth a `logPrint`.

**Recommendation:** update note 117 and the plan's design-decision / Task 2 text to state that over-cap samples are dropped (best-effort cap, inert for breath), and consider adding a `logPrint` on the drop branch to match the existing drop-path logging. No functional code change is otherwise required — the behavior is acceptable for the only current consumer.

## Non-blocking note

- `ModuleInstructionStream.isConnected` getter (line 39) is now unused dead code (no consumer in the repo). The plan deliberately left it; it is pre-existing and unrelated to this change. Mentioned only for completeness.

## Verification performed
- Read both modified files in full; reviewed deletions against prior contents.
- Grepped the whole repo for every removed public symbol and for `sendSample`/`emit`/`breathInstructionStream` callers — no compile-time breakage; signatures and wiring consistent.
- Traced first-`rest` and post-`ready` delivery paths, reconnect cleanup, and the division-by-zero guard — all sound.
- Confirmed the state-channel test fake (`_FakeInstructionStream`) and `_pendingInstruction` path are untouched by the diff.

The one finding is a low-severity spec/plan-vs-code reconciliation (plus a logging-parity suggestion), not a runtime defect.
