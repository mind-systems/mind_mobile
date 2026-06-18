# Plan Review: Fix instruction-stream first frame lost — gate sends on server `ready`

**Plan:** `44-fix-instruction-stream-first-frame-lost-gate-sends-on-server-ready.md`
**Files Reviewed:** 6 (plan + 4 target sources + proto, plus generated stub spot-check)
**Risk Level:** 🟡 Medium

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** WARN — no boundary issues. `ModuleInstructionStream` (transport) and `BreathModuleInstructionStream` (domain) are correctly placed under `lib/Core/Grpc/` and `lib/BreathModule/Core/`. The plan keeps the transport/domain split intact.
- **Rules (`.ai-factory/RULES.md`):** PASS — the "Module Services must be stateless" rule targets package `IXxxService` implementations, not these transport/domain classes (which already legitimately own `StreamController`s). No conflict. Logging-via-`logPrint` is honored throughout.
- **Roadmap (`.ai-factory/ROADMAP.md`):** WARN — this is a `fix` with no explicit roadmap milestone linkage. Non-blocking; note for traceability.
- **skill-context (`aif-review/SKILL.md`):** absent — no project-specific overrides to apply.

## Verified Assumptions (correct)

- ✅ The source-of-truth proto `mind_api/proto/module_instruction_stream.proto` already contains `message StreamReady { int32 max_samples_per_second = 1; int64 timestamp = 2; }` and `StreamReady ready = 3;` in the `oneof event`. The mobile copy `mind_mobile/proto/module_instruction_stream.proto` does **not** — so Task 1 (copy + regen) is genuinely required.
- ✅ Current generated stub has `enum StreamResponse_Event { ack, error, notSet }`; after regen it will gain `ready`, and `StreamReady.maxSamplesPerSecond` will be generated (the field name pattern is confirmed against the existing `StreamAck.maxSamplesPerSecond` accessor at `module_instruction_stream.pb.dart:226`).
- ✅ `gen_proto.sh` regenerates **all** `.proto` files (it `rm -rf`s `OUT_DIR` first) — so other generated files will be rewritten too. This is a no-op if their protos are unchanged; the plan's instruction to verify only `module_instruction_stream` output is fine.
- ✅ Removing `_readyController.add(null)` from `_openStream()` (line 137) is correct, and `readyEvents` has exactly one consumer (`BreathModuleInstructionStream:21`), so re-pointing its semantics from "local open" to "server ready" has no other fan-out.
- ✅ The core fix is sound: routing the first sample into `_outbox` instead of `_streamSink!.add(...)` (current line 82) prevents the first `rest` frame from reaching the sink before the server subscribes. The `_readyTimer` fallback correctly avoids a deadlock against an un-upgraded server.
- ✅ All 16 `[probe]` lines listed for Task 4 exist across exactly the four named files; no probe lines elsewhere in `lib/`.

## Critical Issues

### 1. Task 2 ↔ Task 3 ordering is self-contradictory and cannot work as written

This is the main blocker. The two tasks describe mutually incompatible sequencing for the `ready` branch:

- **Task 2** says: in the `ready` case → set `_isReady = true`, **drain `_outbox` into the sink**, *then* fire `_readyController.add(null)`.
- **Task 3** says: the domain `flushBuffer()` (driven by `readyEvents`) must run **before** the transport drains the outbox — "emitting domain-buffered samples into the outbox while still gated, then letting the single outbox drain emit them FIFO."

These cannot both hold. `StreamController.add()` dispatches listeners on a **microtask**, not synchronously. So when the `ready` branch calls `_readyController.add(null)`, the domain `flushBuffer()` does **not** execute inline — it runs *after* the entire synchronous `ready` branch (including the outbox drain) has finished. By then `_isReady == true` and `_outbox` is already drained/cleared, so `flushBuffer() → emit()` routes the domain backlog **directly to the sink, after** the outbox samples.

Result: the domain `_buffer` (older backlog) is appended **after** the `_outbox` (newer) — the reverse of the FIFO order Task 3 claims to guarantee. Task 3's stated mechanism ("emit domain-buffered samples into the outbox while still gated") is unreachable through `readyEvents`, because the gate is already open by the time the listener fires.

**The plan needs a concrete, deterministic ordering primitive**, e.g. one of:
- Have the transport invoke a **synchronous domain-flush hook** (a callback passed at construction) *before* `_isReady = true` and *before* the outbox drain — so domain samples land in `_outbox` ahead of the existing entries... but note even this gives `[outbox-newer, domain-older]` unless the domain buffer is *prepended*. So ordering must be designed explicitly, not "confirmed."
- Or **merge into a single buffer** owned by the transport, so there is only one drain and one order.
- Or **explicitly accept** that breath-phase instructions tolerate this reordering and document it (see issue #2).

As written, an implementer following Task 2 literally will produce reordered phases on reconnect — exactly the risk Task 3 says it is preventing.

### 2. The two buffers interleave in time — global FIFO is not achievable by "domain-before-outbox"

Task 3 assumes the domain `_buffer` is uniformly *older* than the `_outbox`. It is not. `_canSendNow()` returns `false` both when disconnected **and** when rate-limited (`BreathModuleInstructionStream:68-73`). After gRPC connects but before `ready`:

- a sample that passes the rate gate → `_outbox` (via `emit`)
- the very next sample, if inside the min-interval window → domain `_buffer` (rate-limited)

So a domain-buffered sample can be **newer** than an outbox sample. Any scheme that drains one whole buffer then the other cannot reconstruct true emission order. The plan should either (a) state that breath phases are tolerant of this (the server likely treats phase samples idempotently / by timestamp), making strict ordering a non-goal, or (b) order the merged drain by the sample `timestamp` field. Right now the plan asserts ordering correctness it cannot deliver.

## Other Issues

### 3. Rate-hint surfacing mechanism is undefined (Task 2 → Task 3)

Task 2 says "if `r.ready.maxSamplesPerSecond > 0` capture/surface the rate hint to the domain layer (see Task 3 note)," and Task 3 says "If ... surfaced ... seed `_maxSamplesPerSecond` from it." But **no channel is specified**, and the obvious candidate doesn't fit: `readyEvents` is `Stream<void>` (`ModuleInstructionStream:34,37`) and cannot carry an int. The plan leaves this as a conditional ("If ... surfaced") with no concrete transport. Pin down the mechanism — e.g. change `readyEvents` to `Stream<int?>` / `Stream<StreamReady>`, add a dedicated stream, or emit a synthetic `InstructionAck` through the existing `acks` path (which already feeds `_onDataAck` and updates `_maxSamplesPerSecond`). Reusing the `acks` path is lowest-churn and preserves the existing ack-driven update. Medium priority since it's a correctness-of-first-send nicety, not the core fix.

### 4. Reset-points list is good but verify the `connected`→reopen path

Task 2 lists resetting `_isReady`/`_outbox`/`_readyTimer` on close, the `disconnected` branch, `onError`/`onDone`, and `dispose()`. Good coverage. Note that `_openStream()` is also reached directly from the `connectionState == connected` branch (`ModuleInstructionStream:54`) when `_streamRequested` is set — Task 2 already covers this by re-arming (`_isReady=false`, `_outbox.clear()`) at the top of `_openStream()`, which is correct. Just confirm the timer from a previous cycle is cancelled before starting a new one in `_openStream()` to avoid a leaked `Timer` firing into the new cycle (the plan lists cancel-on-close but a defensive `_readyTimer?.cancel()` at the top of `_openStream()` is advisable).

## Positive Notes

- The root-cause analysis is accurate and the fix targets the right layer (transport-level gate instead of fragile local-open signal).
- Proto-ownership rule is respected (explicit copy, no symlink, no edits to other `.proto` files).
- The `_readyTimer` graceful-degradation path against an un-upgraded server is a thoughtful addition that prevents a hard deadlock.
- Probe-cleanup task (Task 4) is precise and the named lines all exist; the "leave genuine `logPrint` lines intact" caveat is correct (e.g. the real log at `ModuleInstructionStream:74` sits beside a probe at line 73).
- Dependency ordering between tasks (1→2→3→4) is correct.

## Verdict

The core gating strategy is correct and solves the dropped-first-frame bug, but **Tasks 2 and 3 specify an ordering guarantee that is mechanically impossible** with the proposed `readyController`-listener wiring (issue #1), built on an incorrect assumption about buffer age (issue #2), and leave the rate-hint channel undefined (issue #3). These must be resolved before implementation — pick an explicit drain-ordering primitive (single merged buffer or timestamp-sorted drain) and a concrete rate-hint channel, then restate Tasks 2/3 consistently.

Not a pass.
