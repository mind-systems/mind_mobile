# Collapse BreathModuleInstructionStream to a thin mapper

**Date:** 2026-06-19
**Source:** conversation context

## Key Findings

- `BreathModuleInstructionStream` (`lib/BreathModule/Core/BreathModuleInstructionStream.dart`) carries four responsibilities today: payload mapping, buffering (`InstructionBuffer`), rate-limiting (`_maxSamplesPerSecond`/`_lastSendTime`/`_canSendNow`), and a flush trigger (`readyEvents` → `flushBuffer`, `acks` → update rate).
- After the readiness gate (note 114) moves buffering into the transport outbox and eager-connect (note 116) removes the "not connected during a session" case, the domain **buffer** and the **flush-trigger** subscriptions are redundant — the transport (`ModuleInstructionStream`) now owns open lifecycle, buffer-until-`ready`, and reconnect re-arm.
- Rate-limiting is the only non-mapping responsibility with anywhere to go: relocate it into the transport, which already receives `maxSamplesPerSecond` from `ack`/`ready`. Then `BreathModuleInstructionStream` reduces to a thin mapper `(sessionId, phase, durationMs) → InstructionSample → emit`, or dissolves entirely (the state channel calls a small converter into `ModuleInstructionStream.emit`).
- This is a **refactor** (delivery logic pulled down into the transport so modules stay thin), distinct from the lifecycle change in note 116 — a separate reason to revert, done only after 114+116 have actually moved buffering down.

## Details

### Prerequisite

Notes 114 (gate buffers in transport outbox) and 116 (eager-connect removes lazy-open / not-connected case) landed. Until then there is still something to buffer in the domain layer — nothing to collapse.

### The change — `lib/BreathModule/Core/BreathModuleInstructionStream.dart`

- Remove `InstructionBuffer _buffer`, `flushBuffer()`, the `readyEvents` subscription, and the `_canSendNow()`/`_emit()`/buffer branch in `sendSample`.
- Relocate rate-limiting into `ModuleInstructionStream` (transport): it already consumes `maxSamplesPerSecond` via `ack`/`ready`; the rate decision and `_lastSendTime` move next to the outbox/sink. Over-cap samples are dropped (best-effort cap) and logged via `logPrint`. For breath, phase changes are seconds apart vs. the 100 ms cap so the branch is effectively never taken.
- `sendSample` becomes a pure map + `_instructionStream.emit(...)`. Evaluate dissolving the class: if nothing but mapping remains, `BreathModuleStateChannel` can call a small converter directly into `ModuleInstructionStream.emit` and the class is deleted — decide at plan time.
- `lib/Core/Grpc/InstructionBuffer.dart` becomes unused if no other consumer remains — delete it in that case.

### Guards

- Preserve rate-limit **cap** wherever it lands. Over-cap samples are dropped (not deferred) — the cap is a best-effort guard, inert for breath in practice.
- Do NOT touch `BreathModuleStateChannel._pendingInstruction` parking — it is inherent to the `moduleSessionId` round-trip contract, unrelated to buffering.
- Keep the wire contract: `moduleId = 'breath'`, `instructionType = 'breath_phase'`, `data = { phase, durationMs }`.
- Coordinate with note 104 (event-time timestamp) — both touch `sendSample`'s timestamp handling; sequence or merge so neither reverts the other.
- Logging only through `logPrint`.

### Verify

A breath session delivers every phase including the first `rest` (DB check, `session_stream_samples` by `moduleSessionId`); rate-limiting still enforced under rapid phase changes; `BreathModuleInstructionStream` (if kept) holds no buffer/connection/readiness logic; `InstructionBuffer` deleted if orphaned.

## Open Questions

- Keep `BreathModuleInstructionStream` as a thin mapper vs delete it and inline a converter at the state channel — decide at plan time based on how much mapping is left.
