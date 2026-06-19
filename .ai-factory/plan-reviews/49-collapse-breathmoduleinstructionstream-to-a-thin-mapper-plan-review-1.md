# Plan Review: Collapse `BreathModuleInstructionStream` to a thin mapper

**Plan:** `.ai-factory/plans/49-collapse-breathmoduleinstructionstream-to-a-thin-mapper.md`
**Files reviewed:** 6 (plan + 5 source/test files)
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture** (`.ai-factory/ARCHITECTURE.md` present): No boundary violation. The change keeps domain (`lib/BreathModule/`) thin and pushes delivery into the transport (`lib/Core/Grpc/`), which is the correct direction of dependency. The Service-statelessness rule in RULES.md targets module Services, not `BreathModuleInstructionStream` (a domain helper), so removing its `dispose()` does not conflict. **PASS.**
- **Rules** (`.ai-factory/RULES.md` present): No violation. App.dart wiring is untouched (rule: "Never add module-specific state to App.dart"); DI stays constructor-injected (rule: "All dependencies injected via constructor"). **PASS.**
- **Roadmap** (`.ai-factory/ROADMAP.md` present): Direct linkage — the plan implements the open Phase 38 item "Collapse `BreathModuleInstructionStream` to a thin mapper" (line 147), including its stated dependencies on notes 114/116 and coordination with note 104. The plan correctly resolves the roadmap's open question ("evaluate dissolving the class entirely") by keeping the class, with documented justification. **PASS.**

## Verified Against the Codebase

Every grep-based claim in the plan holds:

- `setReadyDrainHook` — sole registrant is `flushBuffer` (BreathModuleInstructionStream:19). Safe to delete after Task 1.
- `acks` getter / `_ackController` — sole consumer is `_dataAckSub` in the domain class (line 20). Safe to delete.
- `isGrpcConnected` **public** getter — only reader is `_canSendNow()` (line 60), removed in Task 1. The **field** `_isGrpcConnected` stays (used in `emit` guard and the connection listener). The plan correctly distinguishes the two.
- `InstructionBuffer` — only `lib/.../BreathModuleInstructionStream.dart` and `test/Core/Grpc/instruction_buffer_test.dart` reference it. Deleting both is consistent.
- `InstructionAck` — only the transport and the domain class reference it. Safe to delete.
- No `breathInstructionStream.dispose()` call exists (App.dart references at lines 94/125/220/239 are field/param/construct/assign only). Removing `dispose()` is safe.
- The state-channel test fake is `class _FakeInstructionStream implements BreathModuleInstructionStream` with `noSuchMethod` (test lines 51–60). Removing `flushBuffer`/`dispose`/private members does **not** break it; only the preserved `sendSample(String, String, int, int)` signature matters, and it is preserved.
- `BreathModuleStateChannel` calls `sendSample(sessionId, phase, durationMs, ts)` at lines 104 and 111 — both unchanged by this plan. Task 1's "keep the parameter list unchanged (note 104)" is honored.

The `InstructionSample` constructor (`sessionId, timestamp, moduleId, instructionType, data`) matches the Task 1 rewrite exactly, and the wire contract (`moduleId:'breath'`, `instructionType:'breath_phase'`, `data:{phase,durationMs}`, `timestamp:timestampMs`) is preserved.

## Critical Issues

None.

## Non-Blocking Notes

1. **Rate-limit semantics are genuinely preserved — but verify the held-sample drain path is understood.** In Task 2, a rate-limited sample (while `_isReady`) is routed to `_outbox`, which is only drained by `_becomeReady() → _drainOutbox()` — i.e. on the next stream (re)open/`ready`. While the tunnel stays ready (the eager-connect steady state), such a held sample is never drained until a reconnect. This is **identical** to the original domain behavior (`_buffer` was also flushed only via the `ready` drain hook), so it is not a regression. Given breath phases change every few seconds against a 10/s cap, the gate is effectively inert and the point is moot. No action required; flagged only so the implementer does not "fix" it by adding a timer.

2. **Minor difference: `_outbox` is cleared on disconnect; the old domain `_buffer` was not.** A rate-limited sample held in `_outbox` would be dropped on a disconnect, whereas the domain `_buffer` persisted across reconnects. Combined with note 1, the impact is negligible (the gate is inert in practice). Acceptable, but worth a one-line awareness check during manual verification under rapid phase changes (already covered by the plan's Verification section).

3. **Ordering under rate-limiting is unchanged.** If sample A is rate-limited (→ `_outbox`) and a later sample B is not (→ sink directly), B reaches the wire before A. This already happened in the original (`_buffer` vs `_emit`) and only matters if the cap ever triggers. No action.

4. **`ack`-case `> 0` guard.** Task 2 moves the `> 0` guard into the transport for the `ack` case. The original transport forwarded `ack.maxSamplesPerSecond` unconditionally and the domain `_onDataAck` applied the `> 0` guard; consolidating the guard in the transport preserves net behavior. Correct.

## Positive Notes

- The "keep the class, don't dissolve it" decision is well-justified (test stability, contract locality, untouched wiring) and resolves the roadmap's open question explicitly rather than silently.
- Task dependencies (1 → 2 → 3, 1 → 4) are correctly ordered; orphan-deletion (Task 3/4) is gated behind the consumer removals.
- The plan correctly scopes out note 104 (timestamp) and note 116 (eager-open guard) as separate revert reasons, avoiding accidental coupling.
- Verification section targets the exact at-risk surfaces: `flutter analyze` for dangling refs, the state-channel test for signature preservation, and a real session for first-`rest` delivery.

PLAN_REVIEW_PASS
