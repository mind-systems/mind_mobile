## Plan Review Summary

**Plan:** 58 — Copy all proto files and regenerate
**Files in Plan:** 3 tasks across 3 phases
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md:** WARN — no architectural concerns. The plan follows the established proto copy pattern documented in both the architecture file and `proto/README.md`. No layer boundaries are crossed.
- **RULES.md:** WARN — no rule violations. The plan involves only proto copy and code generation — no Service, App.dart, or DI changes.
- **ROADMAP.md:** WARN — the plan correctly identifies a discrepancy in milestone 9.1's description. The roadmap mentions "new type names `StateRequest`, `StateResponse`, `ActivityStatus`, `StateEvent`, `StateErrorEvent`", but the API proto still uses `SessionRequest`, `SessionResponse`, `SessionStatus`, `SessionStateEvent`, `SessionErrorEvent`. The plan's "Note on type names" section accurately documents this. The roadmap milestone description should be updated separately to match reality.

### Verification Against Codebase

**Proto file inventory — confirmed:**
- Both repos contain the same 8 `.proto` files (auth, breath_sessions, device, module_instruction_stream, module_state, stats, sync, users).
- Only two files actually differ: `module_state.proto` (Presence types removed in API) and `sync.proto` (comment update).
- The remaining 6 files are byte-identical between repos.

**Removed types — confirmed:**
- `mind_api/proto/module_state.proto` no longer contains `PresenceState` enum, `PresenceCmd` message, or `presence` field (slot 6) in `SessionRequest.oneof command`.
- `mind_mobile/proto/module_state.proto` still contains all three — correctly identified as stale.

**No Dart code breakage — confirmed:**
- `ModuleStateChannel.dart` does not reference `PresenceCmd` or `PresenceState`. It uses: `proto.SessionRequest`, `proto.SessionResponse`, `proto.SessionStateEvent`, `proto.ActivityStartCmd`, `proto.ActivityPauseCmd`, `proto.ActivityResumeCmd`, `proto.ActivityEndCmd`, `proto.ActivityStopCmd`, `proto.SessionStatus`, `proto.ActivityType` — all of which remain in the API proto.
- `ModuleInstructionStream.dart` uses `StreamResponse`, `StreamSample`, `StreamAck`, `SessionErrorEvent` — none removed.
- Zero references to `PresenceCmd` or `PresenceState` exist in any hand-written Dart file.

**Copy command — confirmed safe:**
- `cp mind_api/proto/*.proto mind_mobile/proto/` copies only `.proto` files, leaving `mind_mobile/proto/README.md` (mobile-specific) untouched. Correct.

**gen_proto.sh — confirmed:**
- Script cleans `lib/Core/Grpc/generated/`, then runs `protoc --dart_out=grpc:...` over all `*.proto` files. Produces 32 files (8 protos × 4 outputs each). Correct.

### Critical Issues

None.

### Suggestions

None.

### Positive Notes

- The "Note on type names" section is excellent — it proactively resolves confusion between the roadmap's aspirational description and the actual API state. This prevents the implementer from wasting time looking for renames that haven't happened.
- Task 3's verification is thorough: it lists the specific proto types `ModuleStateChannel.dart` depends on (with one minor omission — `proto.ActivityType` — but since it's not being removed, this doesn't affect correctness).
- The plan correctly scopes itself to only 9.1 (copy + regen) and does not attempt to include 9.2 (Dart code changes), which would be unnecessary since no hand-written code references the removed types.
- The exclusion of `README.md` and `generated/` directory from the copy is explicitly called out — good defensive documentation.

PLAN_REVIEW_PASS
