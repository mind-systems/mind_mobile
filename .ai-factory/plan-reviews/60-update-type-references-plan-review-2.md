## Plan Review: Update type references (round 2)

**Plan file:** `.ai-factory/plans/60-update-type-references.md`
**Risk Level:** 🟡 Medium

### Context Gates

- **ARCHITECTURE.md:** WARN — no architectural concerns. The plan touches only infrastructure-layer files (`ModuleStateChannel.dart`, proto definitions, generated stubs, controller). No domain/module boundary is crossed.
- **RULES.md:** WARN — not applicable. No module services, DI wiring, or constructor injection patterns are affected.
- **ROADMAP.md:** WARN — the plan implements roadmap item 9.2 ("Update type references") but Task 8 only modifies milestone 9.1 without marking 9.2 as complete. See Suggestions below.

### Previous Review Resolution

Review-1 identified that the plan assumed proto types were already renamed when they were not. The plan has been comprehensively rewritten to cover the full chain starting from the proto source of truth. All three critical issues from review-1 are resolved:

- ✅ Plan now begins with the proto rename in `mind_api/proto/` (Phase 1)
- ✅ Covers API-side stub regeneration and controller updates (Phase 2)
- ✅ Then propagates to `mind_mobile/` (Phases 3-4)

### Verification Summary

**Proto files** — Verified `mind_api/proto/module_state.proto` and `mind_api/proto/module_instruction_stream.proto` line-by-line against the plan's Task 1 and Task 2. All line numbers are accurate. The types to rename (`SessionRequest` L80, `SessionResponse` L92, `SessionStatus` L21, `SessionStateEvent` L58, `SessionErrorEvent` L68, `SESSION_STATUS_UNSPECIFIED` L22) and the cross-reference in `module_instruction_stream.proto` (L14, L52, L56, L65) are correct.

**API-side scope** — Confirmed only `module-state.grpc.controller.ts` imports from `proto/generated/module_state`. No other API source file imports proto-generated types from this file. The hand-written `session-status.enum.ts` (`SessionStatus` with string values like `'active'`) is a separate type used by entity/engine/DTO files and is correctly out of scope.

**Mobile-side scope** — Confirmed `ModuleStateChannel.dart` is the only hand-written file using proto types from `module_state.pbgrpc.dart`. `ModuleInstructionStream.dart` imports from `module_instruction_stream.pbgrpc.dart` but only uses `StreamSample`, `StreamResponse`, `StreamResponse_Event`, `StreamAck` — none of which are renamed. `BreathModuleStateChannel.dart` works through the domain `ModuleState` abstraction and doesn't touch proto types. All line number references in Task 6 are accurate (verified all 20+ occurrences).

**Wire compatibility** — Only type names change; field names (`session_state`, `session_error`, `module_session_id`) and field numbers are preserved. Binary compatibility is maintained.

**Oneof discriminators** — The plan correctly identifies that `StateResponse_Event.sessionState` (not `stateState`) is the post-rename enum value, because the proto field name `session_state` is unchanged.

**Codegen scripts** — Verified `npm run proto:gen` (API) and `scripts/gen_proto.sh` (mobile) both regenerate from all `*.proto` files. The mobile script wipes and recreates the output directory, so stale files from old proto names are not a concern.

### Critical Issues

None.

### Suggestions

**1. Task 8 should also mark roadmap item 9.2 as complete**

Roadmap 9.2 is:

> `[ ] **Update type references** — replace SessionRequest, SessionResponse, SessionStatus, SessionStateEvent, SessionErrorEvent with new names in all files that use generated stubs`

This is exactly what the plan implements (Phases 3-4, Tasks 5-7). Since Task 8 already modifies the roadmap file to fix 9.1, it should also mark 9.2 as `[x]` in the same edit. Otherwise the implementer finishes the work but the roadmap still shows it as open.

### Positive Notes

- The plan correctly addresses all findings from review-1 by starting from the proto source of truth and flowing through the entire dependency chain.
- Exhaustive line-number references make implementation mechanical — every occurrence of every type is explicitly listed.
- The "Do not rename" callouts (field names, command types, service name) prevent over-zealous renaming that could break wire compatibility.
- Task 7 (grep verification) is a solid safety net ensuring no references were missed.
- The commit plan (one commit per repo) respects the separate-git-repo structure.

PLAN_REVIEW_PASS
