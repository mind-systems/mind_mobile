# Review: 51 — Regenerate Dart stubs in mind_mobile

## Scope

The only code change is the plan file itself (`.ai-factory/plans/51-regenerate-dart-stubs-in-mind-mobile.md`). The actual work — running `scripts/gen_proto.sh` — is a codegen execution, not a source-code change. Both plan tasks are marked complete.

## Verification

### Generated output matches proto sources

Proto files in `proto/` and stub families in `lib/Core/Grpc/generated/` are a 1:1 match:
`auth`, `breath_sessions`, `device`, `module_instruction_stream`, `module_state`, `stats`, `sync`, `users`.

Each proto produces the expected four files (`.pb.dart`, `.pbenum.dart`, `.pbgrpc.dart`, `.pbjson.dart`) — 32 files total.

### Stale files removed

No `live.pb.dart`, `live.pbgrpc.dart`, `telemetry.pb.dart`, or `telemetry.pbgrpc.dart` exist in the generated directory. Confirmed by directory listing.

### Import integrity

All consumers reference the correct generated paths:

| Consumer | Import | Resolves |
|----------|--------|----------|
| `GrpcClient.dart` | `module_state.pbgrpc.dart` → `ModuleStateServiceClient` | Yes |
| `GrpcClient.dart` | `module_instruction_stream.pbgrpc.dart` → `ModuleInstructionStreamServiceClient` | Yes |
| `ModuleStateChannel.dart` | `module_state.pbgrpc.dart` as `proto` → uses `proto.SessionRequest`, `proto.SessionResponse`, `proto.SessionStatus`, `proto.ActivityType`, etc. | Yes — all types present in generated stub |
| `ModuleInstructionStream.dart` | `module_instruction_stream.pbgrpc.dart` → uses `StreamSample`, `StreamResponse`, `StreamResponse_Event` | Yes — all types present in generated stub |

No file in `lib/` imports the removed `live.*` or `telemetry.*` stubs (grep confirmed zero matches).

### Type compatibility

- `ModuleStateChannel` uses `proto.SessionRequest`, `proto.SessionResponse`, `proto.SessionResponse_Event`, `proto.SessionStatus`, `proto.ActivityStartCmd`, `proto.ActivityPauseCmd`, `proto.ActivityResumeCmd`, `proto.ActivityEndCmd`, `proto.ActivityStopCmd`, `proto.ActivityType`, `proto.SessionStateEvent` — all present in the generated `module_state.pb.dart` / `.pbenum.dart`.
- `ModuleInstructionStream` uses `StreamSample`, `StreamResponse`, `StreamResponse_Event`, `ModuleInstructionStreamServiceClient` — all present in generated `module_instruction_stream.pb.dart` / `.pbgrpc.dart`.
- `GrpcClient` instantiates `ModuleStateServiceClient` and `ModuleInstructionStreamServiceClient` — both class names match the generated client stubs.

### Runtime risks

None identified:
- No database migrations involved.
- No new dependencies added.
- Proto wire format is determined by field numbers in `.proto` files, not by Dart codegen — regeneration does not change the wire format.
- The `gen_proto.sh` script's `rm -rf` + `mkdir -p` guarantees a clean slate with no leftover artifacts.

## Issues found

None.

REVIEW_PASS
