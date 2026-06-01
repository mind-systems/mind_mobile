# Plan Review: Rate-limit `BiometricStreamClient` stream reopen

**Plan:** `102-rate-limit-biometricstreamclient-stream-reopen.md`
**Files Reviewed:** 1 plan, 1 target source file, 1 spec note, RULES.md, ROADMAP.md
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** WARN — no biometric/gRPC/backoff entries found; nothing to align against. No boundary violations: the change is internal to an existing domain-infra class.
- **Rules (`RULES.md`):** PASS — the three project rules concern Module Services (stateless), `App.dart` purity, and constructor DI. `BiometricStreamClient` is domain infrastructure, not a Module Service; the plan adds no `App.dart` state and no new dependencies. None apply.
- **Roadmap (`ROADMAP.md`):** PASS — directly implements the open Phase 26 task at line 239 ("Rate-limit `BiometricStreamClient` stream reopen") and cites its spec note 48 and the deferred Q4 alternative (note 43/44). Milestone linkage is explicit.
- **Skill-context (`.ai-factory/skill-context/aif-review/SKILL.md`):** absent — no project-specific review overrides to apply.

## Verification against codebase

- File path `lib/Biometrics/BiometricStreamClient.dart` is correct.
- Field-placement reference (lines 31–38, near `_replayRing`/`_replayRingMax`/`_sink`/`_responseSub`) matches actual source.
- `_ensureSinkOpen()` line range (85–134) matches exactly, including the `if (_sink != null) return;` early return (line 86), the `StreamController` creation (line 88), the `catch → _teardownSink(); return;` path (lines 120–127), and the trailing replay-ring drain (lines 129–133).
- `_encodeAndAdd`'s `_sink == null` branch (lines 148–153) does enqueue into the replay ring as the plan assumes, so an early-return guard correctly routes samples to the ring with no extra handling.

## Logic trace (correct)

During an outage the sequence behaves as intended:
1. First batch: `_sink == null`, `_lastOpenAttempt == null` → guard passes, timestamp set, open attempted, fails → `_teardownSink()` nulls `_sink`.
2. Next batch ~250 ms later: `_sink == null`, `diff < 2s` → early return; `_sink` stays `null`; samples enqueue to ring.
3. After 2 s: guard passes, reopen attempted.

Placing `_lastOpenAttempt = DateTime.now()` **before** `_sink = StreamController(...)` correctly ensures a failed open (catch path, which `return`s early) still records the attempt and is rate-limited. The `DateTime.now()` usage is retry/backoff control, not a sample timestamp — consistent with spec note 48 §15 and the codebase's "no `DateTime.now()` for samples" convention (which does not apply here).

## Notes (non-blocking)

- **Reconnect-after-healthy is intentionally fast, not throttled.** `_lastOpenAttempt` records the last *open attempt*, including a successful one. If a stream stays healthy for, say, 10 s and then fails, the next reopen sees `diff > 2s` and reconnects immediately; only *repeated rapid* failures get throttled. This is the desirable behavior (prompt recovery from a one-off drop, cooldown only on sustained outage) and matches the spec intent — flagged only so the implementer doesn't "fix" it into a fixed-interval gate.
- **Tradeoff already acknowledged.** Plan note + spec note 48 §19 correctly state the cooldown adds no sample loss versus the status quo (the bounded ring overflows either way during an outage). Resizing `_replayRingMax` is correctly scoped out.

## Positive Notes

- Plan faithfully mirrors spec note 48 with no scope creep; single file, single concern, single commit is appropriate.
- Exact line anchors and the explicit ordering constraint (timestamp assignment before `StreamController`) remove implementation ambiguity.
- Correctly identifies that the existing `_sink == null` replay path requires no new handling — avoids redundant code.

PLAN_REVIEW_PASS
