# Plan Review: Send `client_timestamp_ms` on `ActivityStartCmd`/`ActivityEndCmd`

**Plan:** `71-send-client-timestamp-ms-on-activitystartcmd-activityendcmd-...`
**Files Reviewed:** 5 (plan + 4 source files) + proto pair + roadmap/note
**Risk Level:** 🟢 Low

## Verification Summary

I verified every claim in the plan against the actual codebase:

| Claim | Status |
|-------|--------|
| `mind_api/proto/module_state.proto` defines `optional int64 client_timestamp_ms = 4` on `ActivityStartCmd` and `= 1` on `ActivityEndCmd` | ✅ Confirmed (lines 44, 51) |
| `mind_mobile/proto/module_state.proto` still lacks the fields (regen needed) | ✅ Confirmed — Task 1 is required |
| Generated `module_state.pb.dart` has no `clientTimestampMs` yet | ✅ Confirmed (grep empty) |
| `scripts/gen_proto.sh` exists | ✅ Confirmed |
| `Int64(...)` from `package:fixnum` is the established encoding | ✅ Confirmed — `ModuleInstructionStream.dart:186` `timestamp: Int64(sample.timestamp)`, import at line 3 |
| `ModuleStateChannel.start({required ActivityType type, String? refId})` / `end()` current signatures | ✅ Confirmed (lines 148, 171) |
| `proto.ActivityStartCmd(activityType:, refId:)` and `proto.ActivityEndCmd()` construction sites | ✅ Confirmed (lines 152, 173) |
| BreathModule: `_originWallClock = DateTime.now()` then `_channel.start(...)` at line 80–81 | ✅ Confirmed |
| BreathModule: `_channel.end()` at session complete, line 101 | ✅ Confirmed |
| `_wireTimestamp(offsetMs) = _originWallClock + offsetMs` is the single end-instant source | ✅ Confirmed (line 134–135) |
| MeditationModule: `_channel.start(...)` line 39, `_channel.end()` line 42, re-arm logic | ✅ Confirmed |
| Plan matches spec note `137-send-client-activity-timestamps.md` and ROADMAP line 239 | ✅ Confirmed |

All file paths, line numbers, signatures, and the proto field tags in the plan are accurate. The task ordering (proto sync → channel API → callers) and dependency chain are correct. Backward-compat reasoning (omit field when null → server `now()` fallback) is sound and matches the proto `optional` semantics.

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** No boundary violations. Changes stay within the gRPC channel layer (`lib/Core/Grpc/`) and the two domain state-channel callers — no domain models leak, no module-boundary crossing. Proto remains copy-only per the ownership rule (CLAUDE.md). — **PASS**
- **Rules (`RULES.md`):** No proto/fixnum/codegen rules present; nothing violated. — **PASS**
- **Roadmap (`ROADMAP.md`):** Plan is the direct realization of the open item at line 239 and spec note 137. Linkage present. — **PASS**

## Critical Issues

None.

## Minor / Non-blocking Observations

1. **Stale diagnostic log text (advisory, intentionally deferred).** After this change, the log at `BreathModuleStateChannel.dart:100` —
   `'session complete at offset=… — sending end (server stamps endedAt on receipt)'` —
   becomes factually incorrect: the server will now use the **client** timestamp, not receipt `now()`. The plan (Task 3) and spec note both explicitly mandate leaving the diagnostic logs untouched ("This task neither adds nor removes them"), so this is a deliberate scoping decision, not a plan defect. Flagging only so it is a conscious choice — the parenthetical will mislead a future reader. Optional: drop the `(server stamps endedAt on receipt)` clause in a later cleanup. Not required for this milestone.

2. **Verification depends on server deployment order.** Task list has no explicit verification step, but note 137 covers it (logs should show client `offset=X` ≈ server `durationMs`). Worth confirming the mind_api proto change is actually deployed before judging behavior — against an old server the field is silently ignored (graceful, as documented). This is operational, not a plan gap.

## Positive Notes

- Plan correctly insists on **copy-not-author** for the proto and points at the exact codegen script — fully compliant with the monorepo proto-ownership rule.
- Reuses the existing `Int64(...)` encoding convention rather than inventing a new one, with a concrete reference line.
- Keeps `_wireTimestamp` as the single end-instant source, avoiding a second `DateTime.now()` that would diverge from the `offsetMs` phase axis — a subtle but correct decision.
- Explicit guards on what NOT to touch (pause/resume markers, `stop()`, existing logs) reduce blast radius.
- Meditation channel handled deliberately: lifecycle-only, same clock for start+end yields a correct `durationMs` — no stopwatch needed.

The plan is accurate, well-scoped, and matches both the codebase and the governing spec note.

PLAN_REVIEW_PASS
