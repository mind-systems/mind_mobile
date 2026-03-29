# Plan: Copy all proto files and regenerate

## Context

Sync `mind_mobile/proto/` with the source-of-truth `mind_api/proto/` to pick up the Presence removal (Phase 8.1), then regenerate Dart gRPC stubs so `module_state.pb.dart` no longer contains `PresenceCmd` or `PresenceState`.

**Note on type renames:** The milestone description mentions verifying new type names `StateRequest`, `StateResponse`, `ActivityStatus`, `StateEvent`, `StateErrorEvent`. These renames have **not yet landed** in `mind_api/proto/module_state.proto` — the api proto still uses `SessionRequest`, `SessionResponse`, `SessionStatus`, `SessionStateEvent`, `SessionErrorEvent`. The copy+regenerate will remove `PresenceCmd`/`PresenceState` but will not introduce the renamed types. Skip the rename verification step — it belongs to a future milestone after the api proto is updated.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Copy and regenerate

- [ ] **Task 1: Copy all proto files from mind_api to mind_mobile**
  Files: `proto/*.proto`
  Copy the entire contents of `mind_api/proto/` to `mind_mobile/proto/`, overwriting all existing `.proto` files. Use `cp mind_api/proto/*.proto mind_mobile/proto/` (only `.proto` files — skip `generated/` and `README.md` which are api-specific). Two files differ: `module_state.proto` (removes `PresenceState` enum, `PresenceCmd` message, and `presence` field from `SessionRequest` oneof) and `sync.proto` (comment update only).

- [ ] **Task 2: Regenerate Dart gRPC stubs**
  Files: `lib/Core/Grpc/generated/*`
  Run `bash scripts/gen_proto.sh` from the `mind_mobile/` root. The script wipes `lib/Core/Grpc/generated/`, then runs `protoc --dart_out=grpc:` for all proto files in a single pass. This regenerates all 32 stub files (4 per proto: `.pb.dart`, `.pbgrpc.dart`, `.pbenum.dart`, `.pbjson.dart`).

- [ ] **Task 3: Verify generated stubs are clean**
  Files: `lib/Core/Grpc/generated/module_state.pb.dart`, `lib/Core/Grpc/generated/module_state.pbenum.dart`
  Grep `lib/Core/Grpc/generated/module_state.pb.dart` and `module_state.pbenum.dart` to confirm `PresenceCmd` and `PresenceState` no longer appear. Also confirm `SessionRequest` oneof only has 5 commands (`activityStart` through `activityResume`, no `presence`). No hand-written Dart code references `PresenceCmd` or `PresenceState`, so no additional code changes are required.
