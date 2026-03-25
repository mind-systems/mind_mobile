# Plan: Install toolchain

## Context
Ensure the protobuf compiler (`protoc`) and Dart protoc plugin are installed and verified, and document the pinned versions in `proto/README.md` so any contributor can reproduce the codegen environment.

## Settings
- Testing: no
- Logging: minimal
- Docs: yes (README.md only)

## Tasks

### Phase 1: Verify and activate toolchain

- [x] **Task 1: Verify `protoc` is installed**
  Files: (none — system tooling)
  Run `which protoc` and `protoc --version` to confirm the compiler is available. Expected: `/usr/local/bin/protoc` reporting `libprotoc 34.0`. If `protoc` is not found, install it via `brew install protobuf` and verify again.

- [x] **Task 2: Activate `protoc_plugin` at a pinned version** (depends on Task 1)
  Files: (none — global Dart tooling)
  Run `dart pub global activate protoc_plugin 25.0.0` (pinned version — compatible with `protobuf: ^6.0.0` runtime in `pubspec.yaml`). Verify activation by running `dart pub global list` and confirming `protoc_plugin 25.0.0` appears.

### Phase 2: Document versions

- [x] **Task 3: Create `proto/README.md` with pinned versions and compatibility notes** (depends on Tasks 1–2)
  Files: `proto/README.md`
  Add a `README.md` to the existing `proto/` directory (the directory already contains 8 `.proto` files copied from `mind_api/proto/`). Document:
  - **Prerequisites** section with exact install/activate commands:
    - `brew install protobuf` → `protoc` (`libprotoc 34.0`)
    - `dart pub global activate protoc_plugin 25.0.0`
  - **Version compatibility** section noting that `protoc_plugin 25.0.0` requires `protobuf ^6.0.0` runtime (currently `6.0.0` in `pubspec.lock`) — contributors must keep these versions in sync
  - **Source of truth** note: `.proto` files originate from `mind_api/proto/` and are copied here before codegen — never edit proto files in this repo
  - **Forward reference**: the codegen script (`scripts/gen_proto.sh`) that uses these tools will be added in a follow-up plan (roadmap item 2.2, bullets 3–4)
