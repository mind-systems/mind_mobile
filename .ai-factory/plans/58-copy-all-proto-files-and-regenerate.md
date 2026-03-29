# Plan: Copy all proto files and regenerate

## Context

Sync `mind_mobile/proto/` with the source-of-truth `mind_api/proto/` to remove stale `PresenceCmd`/`PresenceState` types and align the proto comment in `sync.proto`. After copying, regenerate Dart gRPC stubs so the generated code matches the current API contract.

**Note on type names:** The milestone description references verifying "new type names `StateRequest`, `StateResponse`, `ActivityStatus`, `StateEvent`, `StateErrorEvent`". The actual API proto uses `SessionRequest`, `SessionResponse`, `SessionStatus`, `SessionStateEvent`, `SessionErrorEvent` — these names are unchanged and already present in the current stubs. The real change is the **removal** of `PresenceState` enum, `PresenceCmd` message, and the `presence` field (slot 6) from `SessionRequest`'s `oneof command`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Copy proto files

- [x] **Task 1: Copy `.proto` files from `mind_api/proto/` to `mind_mobile/proto/`**
  Files: `mind_mobile/proto/auth.proto`, `mind_mobile/proto/breath_sessions.proto`, `mind_mobile/proto/device.proto`, `mind_mobile/proto/module_instruction_stream.proto`, `mind_mobile/proto/module_state.proto`, `mind_mobile/proto/stats.proto`, `mind_mobile/proto/sync.proto`, `mind_mobile/proto/users.proto`
  Copy only the 8 `.proto` files — do NOT copy `README.md` (the mobile version has its own mobile-specific README) and do NOT copy the `generated/` directory.
  Use: `cp mind_api/proto/*.proto mind_mobile/proto/`
  After copy, verify `mind_mobile/proto/module_state.proto` no longer contains `PresenceState`, `PresenceCmd`, or `presence` field 6 in `SessionRequest`.

### Phase 2: Regenerate Dart stubs

- [x] **Task 2: Run `gen_proto.sh` to regenerate Dart gRPC stubs** (depends on Task 1)
  Files: `mind_mobile/lib/Core/Grpc/generated/*.dart` (all 32 generated files will be regenerated)
  Run from `mind_mobile/` root: `bash scripts/gen_proto.sh`
  The script cleans `lib/Core/Grpc/generated/`, then runs `protoc --dart_out=grpc:...` over all proto files.

### Phase 3: Verify

- [x] **Task 3: Verify generated stubs no longer contain removed types** (depends on Task 2)
  Files: `mind_mobile/lib/Core/Grpc/generated/module_state.pb.dart`, `mind_mobile/lib/Core/Grpc/generated/module_state.pbenum.dart`, `mind_mobile/lib/Core/Grpc/generated/module_state.pbjson.dart`
  Confirm `module_state.pb.dart` does NOT contain `PresenceCmd` or `PresenceState`.
  Confirm `SessionRequest`, `SessionResponse`, `SessionStatus`, `SessionStateEvent`, `SessionErrorEvent` are present (these are the existing and correct type names).
  Confirm `ModuleStateChannel.dart` still compiles — it uses `proto.SessionRequest`, `proto.SessionResponse`, `proto.SessionStateEvent`, `proto.ActivityStartCmd`, `proto.ActivityPauseCmd`, `proto.ActivityResumeCmd`, `proto.ActivityEndCmd`, `proto.ActivityStopCmd`, `proto.SessionStatus` — none of which were removed, so no application code changes are needed.
