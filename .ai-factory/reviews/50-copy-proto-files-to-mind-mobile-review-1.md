# Review: 50 — Copy proto files to mind_mobile

**Files reviewed:** 8 source files + 8 generated stub files + 2 proto files + 1 script
**Risk level:** Low

## Context Gates

- **ARCHITECTURE.md:** `PASS` — Changes are confined to the infrastructure layer (`lib/Core/Grpc/`) and the breath module's channel adapter. No architectural violations.
- **RULES.md:** `PASS` — No state or streams introduced into Services or App.dart inappropriately.
- **ROADMAP.md:** `PASS` — All items from Phase 8.1 and 8.2 are addressed: proto copy, stub regeneration, `GrpcClient`, `ModuleStateChannel`, `ModuleInstructionStream`, `ModuleState`, `ModuleStateEvent`, `BreathModuleStateChannel`, and `App.dart` wiring.

## Verification

### Proto source-of-truth check
- `mind_mobile/proto/module_state.proto` is byte-identical to `mind_api/proto/module_state.proto`.
- `mind_mobile/proto/module_instruction_stream.proto` is byte-identical to `mind_api/proto/module_instruction_stream.proto`.
- Old `live.proto` and `telemetry.proto` are deleted from `mind_mobile/proto/`.

### Generated stubs check
- Old `live.*` and `telemetry.*` generated files are gone.
- New `module_state.*` and `module_instruction_stream.*` generated files are present.
- Generated `ModuleStateServiceClient.trackActivity()` signature matches usage in `ModuleStateChannel._openSessionStream()` (line 71).
- Generated `ModuleInstructionStreamServiceClient.streamData()` signature matches usage in `ModuleInstructionStream._openStream()` (line 95).
- Generated `SessionStateEvent.moduleSessionId` field matches usage in `ModuleStateChannel._processProtoEvent()` (line 117).

### Stale reference sweep
- Grep for `liveSessionId`, `live_session_id`, `liveService`, `LiveService`, `telemetryService`, `TelemetryService` across `lib/**/*.dart` (excluding generated): **zero matches**.
- Grep for `live.pb`, `telemetry.pb`, `live.proto`, `telemetry.proto` across `lib/**/*.dart`: one match in `generated/sync.pb.dart` line 275 — this is a comment inside a generated file originating from `sync.proto` in `mind_api`. Not actionable in this changeset.

## File-by-file review

### `lib/Core/Grpc/ModuleState.dart`
Field `liveSessionId` renamed to `moduleSessionId` across declaration (line 4), constructor (line 8), and factory (line 11). Clean.

### `lib/Core/Grpc/ModuleStateEvent.dart`
Field `liveSessionId` renamed to `moduleSessionId` in `ModuleSessionStarted` (lines 4-5). Clean.

### `lib/Core/Grpc/GrpcClient.dart`
Imports updated. Service fields renamed: `moduleStateService` (line 33), `instructionStreamService` (line 34). Types match generated clients. Clean.

### `lib/Core/Grpc/ModuleStateChannel.dart`
- Import switched to `module_state.pbgrpc.dart` (line 11).
- All proto types updated: `SessionResponse`, `SessionRequest`, `SessionResponse_Event`, `ModuleStateServiceClient`, `SessionStateEvent`.
- RPC call updated: `trackActivity` (line 71) — matches generated stub.
- Internal names consistently renamed: `_moduleStateService`, `_sessionSub`, `_sessionSink`, `_openSessionStream`, `_closeSessionStream`, `_sendSessionRequest`.
- `_processProtoEvent`: local variable renamed to `moduleSessionId` (line 117), correctly passed to `ModuleState(moduleSessionId:` (line 122) and `ModuleSessionStarted(moduleSessionId:` (line 124).
- Section comment updated: "Live stream management" to "Session stream management" (line 67). Clean.

### `lib/Core/Grpc/ModuleInstructionStream.dart`
- Import switched to `module_instruction_stream.pbgrpc.dart` (line 11).
- All proto types updated: `StreamResponse`, `StreamSample`, `StreamResponse_Event`, `StreamAck`, `ModuleInstructionStreamServiceClient`.
- RPC call updated: `streamData` (line 95) — matches generated stub.
- Internal names consistently renamed: `_instructionStreamService`, `_streamSub`, `_streamSink`.
- `_toProto` returns `StreamSample` (lines 142-150). Clean.

### `lib/BreathModule/Core/BreathModuleStateChannel.dart`
- `_liveSessionId` renamed to `_moduleSessionId` (line 20).
- Getter renamed to `moduleSessionId` (line 42).
- `_channelSub` listener reads `moduleState.moduleSessionId` (lines 36-37).
- Local variable in `_handleTelemetry` renamed from `liveId` to `sessionId` (line 87).
- `_flushPending` parameter renamed to `sessionId` (line 103).
- `reset()` clears `_moduleSessionId` (line 111). Clean.

### `lib/Core/App.dart`
- `ModuleStateChannel` constructor: `moduleStateService: grpcClient.moduleStateService` (line 160).
- `ModuleInstructionStream` constructor: `instructionStreamService: grpcClient.instructionStreamService` (line 161).
- Single-line style preserved per App.dart style rule. Clean.

### `scripts/gen_proto.sh`
- Comment updated to reference `module_instruction_stream.proto` imports (lines 11-14). Accurate. Clean.

## Suggestions

**1. Stale log tag `'LiveSession'` in `BreathModuleStateChannel.dart`**

The `dev.log` calls at lines 65, 69, 74, 79, and 123 still use `name: 'LiveSession'` as the log tag. This is cosmetic — it doesn't affect behavior or compilation — but is inconsistent with the rename from "live" to "module session" terminology. Consider updating to `'ModuleSession'` in a follow-up.

## Critical Issues

None.

## Positive Notes

- Complete rename chain from proto field through domain model through event through channel adapter — no dangling references.
- Proto files are byte-identical to `mind_api` source of truth.
- Generated stubs verified against consumer usage — RPC names, message types, and field names all match.
- App.dart wiring updated with correct parameter names, preserving single-line style.
- Internal variable naming is consistent within each file (no `liveXxx` mixed with `sessionXxx`).

REVIEW_PASS
