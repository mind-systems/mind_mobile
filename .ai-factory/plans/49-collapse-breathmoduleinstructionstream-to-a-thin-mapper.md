# Plan: Collapse `BreathModuleInstructionStream` to a thin mapper

## Context
Now that the readiness gate (note 114) buffers in the transport outbox and eager-connect (note 116) keeps the instruction tunnel open for the app lifetime, the domain layer's buffer, flush-trigger, and rate-limit branch are redundant. Strip them so `BreathModuleInstructionStream` becomes a pure `(sessionId, phase, durationMs, timestampMs) → InstructionSample → emit` mapper, and relocate the rate-limit cap into the transport (`ModuleInstructionStream`).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Design decisions (resolved from the spec's open question)

- **Keep `BreathModuleInstructionStream` as a thin mapper — do NOT dissolve it.** Reasons: (1) the existing state-channel test suite (`test/BreathModule/breath_module_state_channel_test.dart`) mocks it via `_FakeInstructionStream implements BreathModuleInstructionStream` and asserts on `sendSample` calls — keeping the class with its current `sendSample` signature leaves that suite untouched; (2) the breath-specific wire contract (`moduleId='breath'`, `instructionType='breath_phase'`, `data={phase,durationMs}`) stays in one named, breath-owned place instead of leaking transport/contract knowledge into `BreathModuleStateChannel`; (3) `App.dart` wiring (`BreathModuleInstructionStream(instructionStream: instructionStream)`) and the `BreathModule.dart` injection stay as-is.
- **Rate-limit behavior:** over-cap samples are dropped and logged via `logPrint`. The `_outbox` route was considered (review-1) but rejected: `_outbox` only drains on `_becomeReady()` and is cleared on reconnect, so it doesn't actually hold-then-deliver in steady state — it just accumulates undeliverable protos. The honest implementation is an explicit drop. The cap is a best-effort guard; for breath, phase changes are seconds apart vs. the 100 ms (10/s) cap, so the branch is effectively never taken.
- **Coordination with note 104:** `sendSample`'s `int timestampMs` parameter (added by note 104) and the caller in `BreathModuleStateChannel._handleInstruction`/`_flushPending` are kept exactly as-is. This plan only removes the buffer/rate/flush logic inside the method body; it does not touch timestamp handling.

## Tasks

### Phase 1: Strip the domain layer to a thin mapper

- [x] **Task 1: Reduce `BreathModuleInstructionStream` to a pure map→emit**
  Files: `lib/BreathModule/Core/BreathModuleInstructionStream.dart`
  Remove the buffer and all delivery logic, leaving only payload mapping:
  - Delete the `InstructionBuffer _buffer` field, `flushBuffer()`, `_emit()`, `_canSendNow()`, the `_maxSamplesPerSecond`/`_lastSendTime` fields, `_onDataAck()`, and the `_dataAckSub` subscription.
  - In the constructor, drop the `_instructionStream.setReadyDrainHook(flushBuffer)` call and the `_instructionStream.acks.listen(_onDataAck)` subscription.
  - Rewrite `sendSample(String sessionId, String phase, int durationMs, int timestampMs)` to build an `InstructionSample` directly and call `_instructionStream.emit(...)` — no `Map` intermediary, no `_canSendNow` branch. Preserve the wire contract: `moduleId: 'breath'`, `instructionType: 'breath_phase'`, `data: {'phase': phase, 'durationMs': durationMs}`, `timestamp: timestampMs`. Keep the parameter list unchanged (note 104).
  - Remove `dispose()` (it only cancelled `_dataAckSub`; no caller invokes `breathInstructionStream.dispose()` — confirmed by grep). Drop the now-unused `dart:async`, `InstructionAck`, and `InstructionBuffer` imports.
  The class should retain only the `ModuleInstructionStream _instructionStream` field, the constructor, and `sendSample`.

### Phase 2: Relocate the rate-limit cap into the transport

- [x] **Task 2: Move rate-limiting into `ModuleInstructionStream`** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleInstructionStream.dart`
  - Add `int _maxSamplesPerSecond = 10;` and `DateTime? _lastSendTime;` fields (mirror the defaults removed from the domain class).
  - In the `_openStream` response handler, capture the rate hint directly into `_maxSamplesPerSecond` whenever `ack.maxSamplesPerSecond > 0` (the `ack` case) and `r.ready.maxSamplesPerSecond > 0` (the `ready` case), replacing the previous "forward via `_ackController`" path.
  - In `emit`, apply the cap on the live-send path only: when `_isReady` and about to write to `_streamSink`, compute `minIntervalMs = 1000 ~/ _maxSamplesPerSecond`; if `_lastSendTime != null` and `DateTime.now().difference(_lastSendTime!).inMilliseconds < minIntervalMs`, log via `logPrint` and return (drop). Otherwise add to the sink and set `_lastSendTime = DateTime.now()`. Leave the existing `_streamSink == null` / not-connected guard at the top of `emit` untouched (that is note 116's territory — separate revert reason). The pre-ready branch (`_outbox.add(proto)` when `!_isReady`) is unchanged. Also reset `_lastSendTime = null` in the `disconnected` handler and at the top of `_openStream` so the rate window starts fresh per connection.

### Phase 3: Delete orphaned plumbing

- [x] **Task 3: Remove the now-unused ack broadcast and ready-drain hook from the transport** (depends on Task 1, Task 2)
  Files: `lib/Core/Grpc/ModuleInstructionStream.dart`, `lib/Core/Grpc/InstructionAck.dart`
  With rate-limiting consumed internally (Task 2) and the domain flush gone (Task 1), these become orphaned:
  - Delete `setReadyDrainHook`, the `_readyDrainHook` field, and the `_readyDrainHook?.call()` line in `_becomeReady()` (its only registrant was the removed `flushBuffer`).
  - Delete the `_ackController` field, the `acks` getter, both `_ackController.add(InstructionAck(...))` constructions in the response handler (keep reading `maxSamplesPerSecond` per Task 2), and the `_ackController.close()` in `dispose()`. Drop the `InstructionAck` import.
  - Delete `lib/Core/Grpc/InstructionAck.dart` — no consumers remain (only this transport and the domain class referenced it).
  - Remove the now-orphaned `bool get isGrpcConnected` getter if nothing references it after Task 1 (the field `_isGrpcConnected` is still used internally by `emit`; only the public getter is dead). Leave the pre-existing unused `isConnected` getter alone unless it is in the way.

- [x] **Task 4: Delete the orphaned `InstructionBuffer` and its test** (depends on Task 1)
  Files: `lib/Core/Grpc/InstructionBuffer.dart`, `test/Core/Grpc/instruction_buffer_test.dart`
  After Task 1 the only consumer of `InstructionBuffer` is gone. Delete both the class and its test file.

## Verification (manual, no new tests)
- `flutter analyze` is clean — no dangling imports/references to `InstructionBuffer`, `InstructionAck`, `acks`, `setReadyDrainHook`, or `flushBuffer`.
- `flutter test test/BreathModule/breath_module_state_channel_test.dart` still passes unchanged (the `sendSample` signature and the `_pendingInstruction` parking are preserved).
- A breath session delivers every phase including the first `rest` (`session_stream_samples` by `moduleSessionId`); rate-limit cap still applied under rapid phase changes; `BreathModuleInstructionStream` holds no buffer/connection/readiness logic.
