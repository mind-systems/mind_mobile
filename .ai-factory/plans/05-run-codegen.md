# Plan: Run codegen

## Context
Execute the proto codegen script to generate Dart gRPC stubs from the `.proto` files already copied into `proto/`, producing output in `lib/Core/Grpc/generated/`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Generate and verify

- [x] **Task 1: Run `scripts/gen_proto.sh`**
  Files: `scripts/gen_proto.sh`, `lib/Core/Grpc/generated/` (created by script)
  Execute `bash scripts/gen_proto.sh` from the `mind_mobile/` root. The script cleans the output directory, runs `protoc --dart_out=grpc:` for all `.proto` files (`auth`, `breath_sessions`, `device`, `live`, `stats`, `sync`, `telemetry`, `users`), and writes generated `.pb.dart`, `.pbenum.dart`, `.pbjson.dart`, and `.pbgrpc.dart` files into `lib/Core/Grpc/generated/`.

- [x] **Task 2: Verify generated output**
  Files: `lib/Core/Grpc/generated/`
  Confirm that every `.proto` file produced the expected set of generated files (`.pb.dart`, `.pbenum.dart`, `.pbjson.dart`, `.pbgrpc.dart`) and that there are no errors or missing imports (e.g. `google/protobuf/struct.proto` used by `telemetry.proto`). List the generated files to confirm completeness.

- [x] **Task 3: Commit generated files**
  Files: `lib/Core/Grpc/generated/`
  Stage all files under `lib/Core/Grpc/generated/` and commit with a descriptive message.
