# Plan: Copy `module_biometric_stream.proto` + regenerate Dart stubs

## Context
Bring the `module_biometric_stream.proto` contract into `mind_mobile` and regenerate Dart gRPC stubs so the new `ModuleBiometricStreamService` becomes available to the mobile app. No application code changes — this is purely a contract sync.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Sync proto and regenerate stubs

- [x] **Task 1: Copy `module_biometric_stream.proto` from `mind_api/` into `mind_mobile/proto/`**
  Files: `proto/module_biometric_stream.proto` (new)
  Copy `/Users/max/projects/mind/mind_api/proto/module_biometric_stream.proto` verbatim to `/Users/max/projects/mind/mind_mobile/proto/module_biometric_stream.proto`. Do not modify, symlink, or transform the file — per project rules, `mind_api/proto/` is the single source of truth and consumers carry an explicit copy. After copying, verify the file sits alongside the existing `module_instruction_stream.proto` and `module_state.proto` siblings in `proto/`.

- [x] **Task 2: Regenerate Dart gRPC stubs via `scripts/gen_proto.sh`** (depends on Task 1)
  Files: `lib/Core/Grpc/generated/module_biometric_stream.pb.dart`, `lib/Core/Grpc/generated/module_biometric_stream.pbenum.dart`, `lib/Core/Grpc/generated/module_biometric_stream.pbgrpc.dart`, `lib/Core/Grpc/generated/module_biometric_stream.pbjson.dart` (all newly generated)
  Run `./scripts/gen_proto.sh` from the `mind_mobile/` repo root. The script cleans `lib/Core/Grpc/generated/` and regenerates stubs for every `.proto` in `proto/` in a single pass, so all existing generated files are also recreated. Prerequisites: `protoc` (Homebrew `brew install protobuf`) and `protoc-gen-dart` (`dart pub global activate protoc_plugin 25.0.0`) must be on `PATH` — the script asserts both and exits otherwise.

- [x] **Task 3: Verify the new service stub is present and the project compiles** (depends on Task 2)
  Files: none modified — verification only
  Confirm `lib/Core/Grpc/generated/module_biometric_stream.pbgrpc.dart` exists and exports `ModuleBiometricStreamServiceClient` (the proto declares `service ModuleBiometricStreamService` in `package mind;`). Run `/usr/local/bin/flutter analyze` from `mind_mobile/` to confirm no compile errors are introduced by the regenerated stubs. The task is complete when the analyzer reports no new errors and the new client class is present.

<!-- orchestrator-sessions
planner: b4ad58f3-d8d4-4f4d-b63e-0dc7bfbb401e
elapsed: 281
implementer: 3f3f2b63-8978-41d1-a81c-de0ff01db314
-->
