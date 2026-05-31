# Plan: Copy updated `module_state.proto` + regenerate Dart stubs

## Context
Sync the local proto snapshot with `mind_api`'s `MEDITATION = 2` addition to the `ActivityType` enum and regenerate the Dart gRPC stubs so the new member is available client-side.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Proto sync & codegen

- [x] **Task 1: Copy updated `module_state.proto` from the API repo**
  Files: `proto/module_state.proto`
  Replace `mind_mobile/proto/module_state.proto` with the exact contents of `../mind_api/proto/module_state.proto`. The only functional change is the `ActivityType` enum gaining `MEDITATION = 2;` (and the accompanying comment update — the old "Only one real member for now" wording is replaced by "Extension point for future activity types."). Do a full file copy rather than a hand edit so the snapshot stays byte-identical to the API source of truth. Do NOT modify any other `.proto` file — this repo never authors proto contracts, it only copies them.

- [x] **Task 2: Regenerate Dart gRPC stubs** (depends on Task 1)
  Files: `lib/Core/Grpc/generated/module_state.pb.dart`, `lib/Core/Grpc/generated/module_state.pbenum.dart`, `lib/Core/Grpc/generated/module_state.pbgrpc.dart`, `lib/Core/Grpc/generated/module_state.pbjson.dart`
  Run `./scripts/gen_proto.sh` from the repo root. The script cleans `lib/Core/Grpc/generated/` and regenerates stubs for all `.proto` files in a single pass, so other generated files will be rewritten too — that is expected and harmless since only `module_state.proto` changed content. Requires `protoc` and `protoc-gen-dart` (see script header for install commands).

- [x] **Task 3: Verify the new enum member and confirm compilation** (depends on Task 2)
  Files: `lib/Core/Grpc/generated/module_state.pbenum.dart`
  Confirm `lib/Core/Grpc/generated/module_state.pbenum.dart` now contains a `MEDITATION` value (value `2`) on the `ActivityType` class. Then ensure the project still compiles with the regenerated stub — run `/usr/local/bin/flutter analyze` (or a dev-flavor build) and confirm no new errors. No application code changes are required; the milestone is complete once the project compiles with the new stub.
