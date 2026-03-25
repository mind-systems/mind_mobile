# Plan: Create `scripts/gen_proto.sh`

## Context
Add a shell script that runs `protoc` to generate Dart gRPC stubs from `.proto` files, and document the command in CLAUDE.md so it's discoverable.

## Settings
- Testing: no
- Logging: minimal
- Docs: yes (CLAUDE.md update is part of the milestone)

## Tasks

### Phase 1: Script and documentation

- [x] **Task 1: Create `scripts/gen_proto.sh`**
  Files: `scripts/gen_proto.sh`
  Create the script with the following behavior:
  - Set `#!/usr/bin/env bash` shebang and `set -euo pipefail` for safety.
  - `cd` to the repo root (`SCRIPT_DIR` → `dirname "$0"` → parent) so the script works regardless of where it's invoked from.
  - Define variables: `PROTO_DIR=proto`, `OUT_DIR=lib/Core/Grpc/generated`.
  - Clean the output directory before generation (`rm -rf "$OUT_DIR"`) and recreate it (`mkdir -p "$OUT_DIR"`). This ensures stale files from removed or renamed `.proto` files don't linger.
  - Verify `protoc` and `protoc-gen-dart` are available (`command -v` check), exit with a clear error message if missing.
  - Run `protoc` once with all `.proto` files globbed: `protoc --dart_out=grpc:"$OUT_DIR" -I"$PROTO_DIR" "$PROTO_DIR"/*.proto`. This generates both protobuf and gRPC service stubs in a single invocation. Note: `telemetry.proto` imports `google/protobuf/struct.proto` (a well-known type). Standard protoc installations (e.g. `brew install protobuf`) include these on the default include path. Add a comment in the script noting this dependency, so failures from non-standard installs are easier to diagnose.
  - Print a short success message listing the output directory.
  - After creating the file, set the executable bit: `chmod +x scripts/gen_proto.sh`.

- [x] **Task 2: Document the command in CLAUDE.md**
  Files: `CLAUDE.md`
  In the `## Commands` code block (after the `flutter pub add` line, before the closing ` ``` `), add:
  ```
  # Regenerate gRPC Dart stubs (after proto files change)
  ./scripts/gen_proto.sh
  ```
  This keeps it next to the existing "Regenerate Drift ORM code" command.

- [x] **Task 3: Update `proto/README.md` codegen section**
  Files: `proto/README.md`
  Replace the placeholder text _"The codegen script (`scripts/gen_proto.sh`) will be added in a follow-up plan (roadmap item 2.2)."_ with actual usage instructions:
  ```
  Run the codegen script from the repository root:

      ./scripts/gen_proto.sh

  This generates Dart stubs into `lib/Core/Grpc/generated/`. Re-run after copying updated `.proto` files from `mind_api/proto/`.
  ```
