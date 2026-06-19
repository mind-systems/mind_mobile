# Plan Review: Fix biometric-stream first batch lost on open — gate sends on server `ready`

**Plan:** `46-fix-biometric-stream-first-batch-lost-on-open-gate-sends-on-server-ready.md`
**Risk Level:** 🟢 Low
**Verdict:** Solid — ready to implement.

## Summary

The plan gates outbound biometric batches and the replay-ring drain on a server `ready`
frame, re-armed on every `_ensureSinkOpen`, with a 5 s fallback timer to avoid deadlock
against an un-upgraded server. It is a direct, faithful port of the already-shipped
instruction-stream fix (`ModuleInstructionStream`, ROADMAP line 135 / note 114) and matches
note 115 (`115-biometric-stream-readiness-gate-client.md`) point-for-point.

I verified every codebase assumption the plan makes. They all hold.

## Context Gates

- **Architecture** — `WARN`/clear. `BiometricStreamClient` lives in `lib/Biometrics/`
  (infrastructure), owns its own `StreamController`/`StreamSubscription` and manages its own
  lifecycle. It is **not** a Module Service, so the `RULES.md` "Services must be stateless"
  rule does not apply. No boundary violation.
- **Rules** — clear. No `RULES.md` rule is touched; the change adds state to an
  already-stateful infrastructure client, not to a Module Service or `App.dart`.
- **Roadmap** — linked. Maps directly to the open task at `ROADMAP.md` line 137
  ("Fix: biometric-stream first batch lost on open — gate sends on server `ready`").
- **Skill-context** — `.ai-factory/skill-context/aif-review/SKILL.md` not present; no project
  overrides to apply.

## Verification of plan assumptions (all confirmed)

- **Proto drift is real.** `mind_api/proto/module_biometric_stream.proto` already defines
  `BioStreamReady { int32 max_samples_per_second = 1; int64 timestamp = 2; }` and the
  `BioStreamReady ready = 3;` oneof arm. The `mind_mobile/proto/` copy still lacks both —
  so Task 1 (copy verbatim + regen) is genuinely required, not a no-op.
- **Generated stubs do not yet have `ready`.** Current
  `lib/Core/Grpc/generated/module_biometric_stream.pb.dart` has
  `enum BioStreamResponse_Event { ack, error, notSet }` and no `BioStreamReady` type. After
  regen the plan's referenced symbols (`BioStreamResponse_Event.ready`, `r.ready`,
  `BioStreamReady`) will exist — consistent with how `StreamResponse_Event.ready` / `r.ready`
  already work in the instruction stream.
- **`gen_proto.sh` regenerates all stubs in one pass** (`rm -rf OUT_DIR`, then
  `protoc … proto/*.proto`). Copying the proto first (Task 1) is therefore mandatory —
  regen alone would not add `ready`. Confirmed.
- **Target file shape matches the plan.** `_ensureSinkOpen()`, the post-open replay drain
  block (lines 128–132), the `whichEvent()` switch (ack/error/notSet), the `_sink == null`
  guard in `_encodeAndAdd` (lines 147–152), `_enqueueReplay`, `_teardownSink`, `dispose`,
  the `_lastOpenAttempt` cooldown, and `_replayRingMax = 75` all exist exactly where the
  plan says. `dart:async` is already imported.
- **Reference implementation confirms the design.** `ModuleInstructionStream` already
  implements the identical gate (`_isReady`, `_readyTimer`, 5 s `_readyTimeout`, drain on
  `ready`, fallback flush on timeout, cancel on teardown/dispose). The plan reuses this
  proven shape.

## Edge-case analysis (no deadlocks found)

- **Ordering in the `ready` arm and fallback timer:** both set `_isReady = true` *before*
  calling `_encodeAndAdd(replay)`, so the new Task 4 pre-ready guard (`!_isReady → enqueue`)
  does not re-divert the drain back into the ring. Correct.
- **Cooldown path:** if `_ensureSinkOpen` returns early (2 s cooldown, `_sink == null`),
  samples hit the existing `_sink == null` guard and enqueue to replay; the next successful
  open starts the fallback timer. No lost-drain, no deadlock.
- **Late `ready` after fallback fired:** ready arm re-sets `_isReady = true` (already true),
  cancels an already-null/fired timer, drains an empty ring — harmless.
- **Stale timer after stream error:** `_teardownSink` cancels `_readyTimer` (per Task 3), so
  a torn-down stream cannot fire a spurious drain into a closed sink.

## Minor observations (non-blocking — no action required)

1. **`_isReady` is not reset to `false` inside `_teardownSink()`** (the plan resets it only
   at the top of `_ensureSinkOpen`). This is safe: between teardown and the next open,
   `_sink == null`, so `_encodeAndAdd`'s first guard routes samples to the replay ring
   regardless of `_isReady`, and the next open re-arms the flag. Resetting it in
   `_teardownSink` too would be marginally tidier (and matches the instruction stream's
   onError/onDone handlers), but it is not a correctness issue.
2. **Drain is FIFO, not timestamp-sorted.** The instruction-stream reference sorts its outbox
   by timestamp before draining; this plan drains the `Queue` in insertion order. That is
   correct here because samples are enqueued in arrival order and the ring is a single FIFO —
   no sort needed. Worth being aware of, not a defect.
3. **`gen_proto.sh` rewrites the entire `generated/` dir.** If any *other* `mind_mobile`
   proto copy has drifted from `mind_api`, regen could surface unrelated diffs. During
   implementation, confirm the diff is limited to `module_biometric_stream.*` (as the plan's
   verification step already implies). Task 1 correctly forbids editing other `.proto` files.
4. **Task 1 lists only `.pb.dart` and `.pbgrpc.dart` as outputs**, but regen also rewrites
   `.pbenum.dart` / `.pbjson.dart` for the file. Cosmetic — the verification target
   (`BioStreamReady` + `ready` getter in `.pb.dart`) is correct.

## Positive notes

- Correctly insists on copying the proto from the single source of truth rather than
  hand-editing it (honors the repo's proto-ownership rule).
- Fallback timer + un-upgraded-server degradation path is explicitly designed in, mirroring
  the proven instruction-stream fix — no deadlock risk.
- Reuses the existing bounded drop-oldest ring as the pre-ready buffer instead of adding a
  second buffer; honors the "low data-loss cost" judgment and keeps the cooldown/ring cap
  untouched.
- Task dependencies (1→2→3→4) and the single-commit framing are correct and minimal.

PLAN_REVIEW_PASS
