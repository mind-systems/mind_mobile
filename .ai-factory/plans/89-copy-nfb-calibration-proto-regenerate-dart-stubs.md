# Plan: Copy `nfb_calibration.proto` + regenerate Dart stubs

## Context
Bring the new `nfb_calibration.proto` contract (authored in `mind_api`) into the mobile repo and regenerate the Dart gRPC stubs so subsequent BCI calibration work can reference `NfbCalibrationServiceClient` and the calibration DTOs from `lib/Core/Grpc/generated/`. No application code is changed; the milestone ends when the project compiles with the new stubs present.

Prerequisite: `mind_api` Phase 20 Task 1 (proto authored). Verified — `mind_api/proto/nfb_calibration.proto` exists.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Sync proto + regenerate

- [x] **Task 1: Copy `nfb_calibration.proto` from `mind_api` to `mind_mobile`**
  Files: `proto/nfb_calibration.proto` (new)
  Copy `mind_api/proto/nfb_calibration.proto` into `mind_mobile/proto/nfb_calibration.proto` verbatim (no edits, no symlinks — per the monorepo rule in root `CLAUDE.md` "Proto contract ownership"). Use a plain `cp` command from the monorepo root:
  ```bash
  cp mind_api/proto/nfb_calibration.proto mind_mobile/proto/nfb_calibration.proto
  ```
  After copying, confirm `mind_mobile/proto/` now lists `nfb_calibration.proto` alongside the other `.proto` files (`auth.proto`, `bci_devices.proto`, `breath_sessions.proto`, `device.proto`, `module_biometric_stream.proto`, `module_instruction_stream.proto`, `module_state.proto`, `stats.proto`, `sync.proto`, `users.proto`).

- [x] **Task 2: Regenerate Dart gRPC stubs** (depends on Task 1)
  Files: `lib/Core/Grpc/generated/` (regenerated wholesale by the script)
  From `mind_mobile/`, run:
  ```bash
  ./scripts/gen_proto.sh
  ```
  The script wipes `lib/Core/Grpc/generated/` and regenerates stubs for every `.proto` in `proto/` in one `protoc` invocation, so all existing stubs (auth, bci_devices, breath_sessions, etc.) are regenerated alongside the new calibration stubs. Expect successful exit with `Done. Dart stubs written to lib/Core/Grpc/generated/`.

  If `protoc` or `protoc-gen-dart` is missing, install per the script's header comments:
  - `brew install protobuf`
  - `dart pub global activate protoc_plugin 25.0.0`

- [x] **Task 3: Verify `NfbCalibrationServiceClient` and calibration stubs are present** (depends on Task 2)
  Files: `lib/Core/Grpc/generated/nfb_calibration.pb.dart`, `lib/Core/Grpc/generated/nfb_calibration.pbgrpc.dart`, `lib/Core/Grpc/generated/nfb_calibration.pbenum.dart`, `lib/Core/Grpc/generated/nfb_calibration.pbjson.dart`
  Confirm these four files exist under `lib/Core/Grpc/generated/`. Open `nfb_calibration.pbgrpc.dart` and confirm a `class NfbCalibrationServiceClient extends $grpc.Client` declaration is present (this is the generated gRPC client the milestone requires). Open `nfb_calibration.pb.dart` and confirm a `class NfbCalibrationRecord` message class is present (matches the `NfbCalibrationRecord` message in the source `.proto`).

- [x] **Task 4: Compile-check the project** (depends on Task 3)
  Files: none modified
  From `mind_mobile/`, run a static analysis pass to confirm the new stubs do not introduce compilation errors and that the regeneration did not break any existing import:
  ```bash
  /usr/local/bin/flutter analyze
  ```
  Acceptable outcome: no new errors introduced by the proto regeneration. Pre-existing warnings/infos unrelated to the generated calibration files may remain — they are out of scope for this milestone. If `flutter analyze` surfaces errors inside `lib/Core/Grpc/generated/nfb_calibration.*` itself, halt and report — the stubs are malformed and the regeneration step needs to be revisited.

## Notes
- No edits to any file outside `proto/nfb_calibration.proto` and the regenerated `lib/Core/Grpc/generated/` tree.
- No `pubspec.yaml` changes, no DI wiring, no service/notifier/repository changes — that is explicitly deferred to subsequent BCI calibration milestones.
- Do NOT commit — per global rules, commits require explicit user permission. Leave changes staged-or-unstaged as produced by the script.

<!-- orchestrator-sessions
planner: 334927c7-281d-4cae-850f-51b9e7c939d1
elapsed: 319
implementer: 60ef092e-5416-46d2-bb33-2679faf86fa1
-->
