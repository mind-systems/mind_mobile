# Plan: Regenerate Dart stubs in mind_mobile

## Context
Run the proto codegen script to regenerate all Dart gRPC stubs from the current `.proto` files in `proto/`, ensuring the generated directory reflects the latest contract (including `module_state` and `module_instruction_stream`) and no stale files (`live`, `telemetry`) remain.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Regenerate stubs

- [x] **Task 1: Run gen_proto.sh**
  Files: `scripts/gen_proto.sh`, `lib/Core/Grpc/generated/*`
  Run `bash scripts/gen_proto.sh` from the `mind_mobile/` root. The script wipes `lib/Core/Grpc/generated/`, then invokes `protoc --dart_out=grpc:` on every `.proto` file in `proto/`. No code changes needed — just execute the script.

- [x] **Task 2: Verify generated output**
  Files: `lib/Core/Grpc/generated/*`
  After the script completes, confirm:
  1. **New files present:** `module_state.pb.dart`, `module_state.pbgrpc.dart`, `module_instruction_stream.pb.dart`, `module_instruction_stream.pbgrpc.dart` exist in `lib/Core/Grpc/generated/`.
  2. **Old files gone:** no `live.pb.dart`, `live.pbgrpc.dart`, `telemetry.pb.dart`, `telemetry.pbgrpc.dart` in the output directory (the script's `rm -rf` + fresh `mkdir -p` guarantees this, but verify explicitly).
  3. **Full set intact:** all expected stub families are present — `auth`, `breath_sessions`, `device`, `module_instruction_stream`, `module_state`, `stats`, `sync`, `users` (each produces `.pb.dart`, `.pbenum.dart`, `.pbgrpc.dart`, `.pbjson.dart`).
  4. **No import breakage:** existing consumers (`GrpcClient.dart`, `ModuleStateChannel.dart`, `ModuleInstructionStream.dart`) import from `generated/module_state.pb.dart` and `generated/module_instruction_stream.pb.dart` — confirm those import paths still resolve (file names unchanged).
