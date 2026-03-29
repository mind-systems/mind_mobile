## Code Review: Update type references

**Plan file:** `.ai-factory/plans/60-update-type-references.md`

### Scope of Changes

**mind_api/** (unstaged):
- `proto/module_state.proto` — 5 type renames + sentinel rename + comment updates
- `proto/module_instruction_stream.proto` — `SessionErrorEvent` → `StateErrorEvent` (field type + 3 comments)
- `src/realtime/module-state.grpc.controller.ts` — all imports and usages updated

**mind_mobile/** (staged):
- `proto/module_state.proto` — identical to mind_api copy
- `proto/module_instruction_stream.proto` — identical to mind_api copy
- `lib/Core/Grpc/generated/module_state.pb.dart`, `.pbenum.dart`, `.pbgrpc.dart`, `.pbjson.dart` — regenerated stubs
- `lib/Core/Grpc/generated/module_instruction_stream.pb.dart`, `.pbjson.dart` — regenerated stubs
- `lib/Core/Grpc/ModuleStateChannel.dart` — all proto type references updated
- `.ai-factory/ROADMAP.md` — milestone 9.1 split, 9.2 marked complete

### Verification

**Proto file identity** — `diff` confirms `mind_api/proto/` and `mind_mobile/proto/` are byte-identical for both `.proto` files. Source of truth is respected.

**Wire compatibility preserved** — only message/enum type names changed. Field numbers, field names (`session_state`, `session_error`, `module_session_id`, `is_paused`), and enum integer values are all unchanged. Binary wire format is identical before and after. Rolling deployments are safe.

**Generated stubs match proto** — confirmed the regenerated Dart stubs define exactly the new types:
- `ActivityStatus` (enum, values 0-6 unchanged)
- `StateEvent`, `StateErrorEvent` (messages)
- `StateRequest`, `StateRequest_Command` (message + oneof enum)
- `StateResponse`, `StateResponse_Event` (message + oneof enum)

Zero occurrences of old names (`SessionRequest`, `SessionResponse`, `SessionStatus`, `SessionStateEvent`, `SessionErrorEvent`) in the generated code, except one proto-sourced comment: `/// Maps to SessionStatus enum in src/realtime/enums/session-status.enum.ts.` — this is correct because the NestJS domain enum IS still called `SessionStatus`.

**Oneof discriminator values** — `StateResponse_Event.sessionState`, `.sessionError`, `.notSet` — derive from proto field names (unchanged), not message type names. The Dart code uses these correctly (e.g., `proto.StateResponse_Event.sessionState` on L75).

**No missed references** — grep for `proto.Session(Request|Response|Status|StateEvent|ErrorEvent)` across all of `lib/` returns zero matches. The only non-generated files referencing "Session" are breath session CRUD types (`CreateSessionRequest`, etc.) in `breath_sessions.pb.dart` — completely unrelated.

**ModuleInstructionStream.dart unaffected** — imports from `module_instruction_stream.pbgrpc.dart` and uses `StreamSample`, `StreamResponse`, `StreamResponse_Event`, `StreamAck`. None were renamed. The `StreamResponse.error` field type changed to `StateErrorEvent` in the generated code, but the file accesses it as `r.error.code` / `r.error.message` — never by type name.

**GrpcClient wiring unaffected** — `ModuleStateServiceClient` class name is unchanged (service name `ModuleStateService` was not part of the rename).

**mind_api controller** — all 3 imported names updated (`StateRequest`, `StateResponse`, `ActivityStatus`). All 10 `SessionStatus.*` enum usages → `ActivityStatus.*`. All `Subscriber<SessionResponse>` → `Subscriber<StateResponse>`. Error message string updated (`'Empty StateRequest'`). Inline object literals (`{ sessionState: { ... } }`, `{ sessionError: { ... } }`) use field names, not type names — no changes needed, and none were made. Correct.

**mind_api instruction stream controller** — does NOT import any renamed types. Imports only `StreamSample`, `StreamResponse`, `ModuleInstructionStreamServiceController`, `ModuleInstructionStreamServiceControllerMethods`. No changes needed, none made.

### Critical Issues

None.

### Suggestions

**1. Regenerate mind_api NestJS stubs before committing**

The mind_api `proto/generated/` directory is gitignored. The proto files and controller have been updated, but `npm run proto:gen` must be run before the controller can compile. The generated stubs need to export `StateRequest`, `StateResponse`, `ActivityStatus` for the import on L7-15 to resolve. Verify with `npm run build` or `npm test` after regeneration.

### Positive Notes

- Clean mechanical rename — every occurrence is accounted for, nothing was missed, nothing was over-renamed.
- Proto field names and field numbers preserved, maintaining full wire compatibility.
- Proto files are byte-identical across repos, respecting the source-of-truth ownership rule.
- Roadmap correctly updated: 9.1 split into presence removal and type rename verification; 9.2 marked complete.

REVIEW_PASS
