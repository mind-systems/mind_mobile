# Plan Review 2: Fix instruction-stream first frame lost — gate sends on server `ready`

**Plan:** `44-fix-instruction-stream-first-frame-lost-gate-sends-on-server-ready.md`
**Files Reviewed:** 8 (plan + review-1 + 4 target sources + proto src/dst + generated stub)
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** PASS — transport/domain split preserved. The drain hook is a plain `void Function()`, so no domain type leaks into the transport layer; dependency direction stays domain→transport (same as the existing stream subscriptions). Boundary intact.
- **Rules (`.ai-factory/RULES.md`):** PASS — logging stays on `logPrint` throughout. No stateless-service rule applies to these transport/domain classes.
- **Roadmap (`.ai-factory/ROADMAP.md`):** WARN — this is a `fix` with no explicit milestone linkage. Non-blocking; noted for traceability (carried over from review-1).
- **skill-context (`aif-review/SKILL.md`):** absent — no project-specific overrides.

## Review-1 Issues — Resolution Check

All four issues from plan-review-1 are concretely resolved:

1. **Microtask reordering (Critical #1) → RESOLVED.** The plan replaces the `readyEvents`-listener flush with a **synchronous drain hook** (`setReadyDrainHook(flushBuffer)`). `_becomeReady()` calls `_readyDrainHook?.call()` while `_isReady == false`, so `flushBuffer() → emit()` routes the domain backlog into the still-gated `_outbox` synchronously — no `StreamController.add()` microtask, no open-gate window. This is mechanically sound: verified `emit()` routes to `_outbox` whenever `_isReady == false` and the sink is non-null, which holds at hook-call time.
2. **Interleaved buffer ages (Critical #2) → RESOLVED.** A single timestamp-sorted drain (`_outbox.sort((a,b) => a.timestamp.compareTo(b.timestamp))`) reconstructs true emission order regardless of which buffer a sample passed through. `StreamSample.timestamp` is `Int64` and `compareTo` is valid. The plan explicitly accepts ties on equal timestamps — acceptable given breath phases are seconds apart.
3. **Undefined rate-hint channel (#3) → RESOLVED.** A synthetic `InstructionAck(sessionId: '', receivedCount: 0, droppedCount: 0, maxSamplesPerSecond: r.ready.maxSamplesPerSecond, timestamp: r.ready.timestamp.toInt())` is emitted through the existing `acks` path. Verified: `_onDataAck` reads only `maxSamplesPerSecond`, so the zero counts are harmless, and `acks` has exactly one consumer (`_dataAckSub` → `_onDataAck`). `InstructionAck` field set matches exactly.
4. **Leaked-timer defense (#4) → RESOLVED.** `_openStream()` now starts with `_readyTimer?.cancel()` before re-arming.

## Verified Assumptions (correct)

- ✅ Source proto `mind_api/proto/module_instruction_stream.proto` already carries `message StreamReady { int32 max_samples_per_second = 1; int64 timestamp = 2; }` and `StreamReady ready = 3;` in the `oneof event`. The mobile copy does **not** — Task 1 (copy + regen) is genuinely required.
- ✅ Current generated stub has `enum StreamResponse_Event { ack, error, notSet }` (line 244); after regen it gains `ready`. The `maxSamplesPerSecond` accessor pattern is confirmed against the existing `StreamAck.maxSamplesPerSecond` (`.pb.dart:226`). So `r.ready`, `StreamResponse_Event.ready`, `r.ready.maxSamplesPerSecond`, and `r.ready.timestamp` will all be generated.
- ✅ `gen_proto.sh` `rm -rf`s `OUT_DIR` and regenerates all `.proto` in one pass — a no-op for unchanged files. Plan's "verify only `module_instruction_stream` output" is fine.
- ✅ Re-pointing semantics: `readyEvents` and `flushBuffer` each have exactly one consumer (`BreathModuleInstructionStream:21` and `:47`), confirmed by grep. Removing `_instructionReadySub` and its `dispose()` cancel is safe.
- ✅ `emit()` open-on-null-sink path: after `_openStream()` re-arms (`_isReady = false`), the first sample routes to `_outbox` instead of the sink — this is the core fix and is correctly specified.
- ✅ Reset coverage (disconnected branch, onError, onDone, dispose, plus re-arm at top of `_openStream`) is complete. Resetting in both onError/onDone and the disconnected branch is redundant but harmless.

## Minor Issues (non-blocking)

1. **Probe count is wrong: 18, not 16.** Task 4 states "16 lines total." Actual counts: `ModuleInstructionStream.dart` 6, `BreathModuleInstructionStream.dart` 3, `ModuleStateChannel.dart` 3, `BreathModuleStateChannel.dart` 6 → **18 total**. The task's closing guard ("confirm no `[probe]` substring remains anywhere in `lib/`") makes the cleanup self-correcting, so completeness is not at risk — but the stated number should be corrected to 18 to avoid an implementer stopping early.

2. **`_onReadyTimeout` could defensively guard `_streamSink == null`.** `_drainOutbox()` calls `_streamSink!.add(...)`; if the timer ever fired after teardown without being cancelled, that is an NPE. The plan cancels the timer at every teardown point, so this is covered in practice — a `if (_isReady || _streamSink == null) return;` guard would be belt-and-suspenders only. Optional.

3. **`_readyController` becomes listener-less.** After Task 3 removes the `readyEvents` listener, `_readyController.add(null)` in `_becomeReady()` has no consumer. The plan states this intentionally (retained as a post-drain notification / stable API). Harmless; flagged only for awareness.

## Positive Notes

- The redesign targets the exact failure mechanism review-1 identified and replaces the impossible-to-order `readyController`-listener wiring with a deterministic synchronous hook + single sorted drain. The ordering argument now actually holds.
- Rate-hint reuse of the `acks` path is the lowest-churn option and preserves the existing ack-driven update — exactly as review-1 recommended.
- The `_readyTimer` graceful-degradation path against an un-upgraded server prevents a hard deadlock, and the Verify section's "deploy server-first; the timeout is a safety net, not a license to deploy mobile-first" caveat is the correct operational stance.
- Proto-ownership respected (explicit copy, no symlink, no edits to other `.proto`).
- Task dependency ordering (1→2→3→4) is correct.

## Verdict

The plan resolves every blocking issue from review-1 with concrete, mechanically-correct primitives. The remaining items are a cosmetic count error (self-corrected by the task's own final check) and two optional hardening notes — none block implementation.

PLAN_REVIEW_PASS
