# Code Review: 04-create-scripts-gen-proto-sh

**Plan:** `.ai-factory/plans/04-create-scripts-gen-proto-sh.md`
**Files changed:** `scripts/gen_proto.sh` (new), `CLAUDE.md` (modified), `proto/README.md` (modified)
**Risk Level:** Low

## Verification

### scripts/gen_proto.sh

- **Shebang and safety:** `#!/usr/bin/env bash` + `set -euo pipefail` — correct.
- **Path resolution:** `SCRIPT_DIR` → `dirname "$0"` → `REPO_ROOT` via `..` — works regardless of invocation directory.
- **Tool checks:** `command -v protoc` and `command -v protoc-gen-dart` run *before* `rm -rf`, so if either is missing the script exits without touching the filesystem. Error messages include install commands and go to stderr. Correct.
- **Clean + recreate:** `rm -rf "$OUT_DIR"` then `mkdir -p "$OUT_DIR"` ensures idempotency with no stale files. Matches plan.
- **protoc invocation:** `protoc --dart_out=grpc:"$OUT_DIR" -I"$PROTO_DIR" "$PROTO_DIR"/*.proto` — single-pass glob, generates both protobuf and gRPC stubs.
- **Import chain verified:**
  - `telemetry.proto` → `google/protobuf/struct.proto` (well-known type, resolved by protoc's built-in include path) + `live.proto` (local, resolved by `-I"$PROTO_DIR"`)
  - `users.proto` → `auth.proto` (local, resolved by `-I"$PROTO_DIR"`)
  - All other 6 proto files have no imports — glob approach handles everything.
- **Well-known types comment:** Lines 11–14 document the `google/protobuf/struct.proto` dependency and troubleshooting steps. Addresses the reviewer feedback from plan review.
- **Executable bit:** Confirmed set (`-rwxr-xr-x`).

### CLAUDE.md

- New entry placed after `flutter pub add` and before the closing code fence (line 27–28). Position is correct — sits next to the existing "Regenerate Drift ORM code" command. Comment format matches the existing style.

### proto/README.md

- Placeholder text fully replaced with concrete usage instructions. `./scripts/gen_proto.sh` command, output directory, and "re-run after copying" guidance are all present. Final line count (40 lines) is clean.

## Issues

None found.

## Suggestions

**1. Consider whether `lib/Core/Grpc/generated/` needs a `.gitignore` entry**

The directory is not gitignored. The project convention is to commit generated code (Drift's `Database.g.dart` is committed), so this is consistent. However, protoc generates ~4 files per `.proto` (`.pb.dart`, `.pbenum.dart`, `.pbjson.dart`, `.pbgrpc.dart`), so 8 proto files will produce ~32 generated files. If the team prefers to keep these out of version control and regenerate on checkout, a `.gitignore` entry would be needed. Either approach is valid — just flagging the decision point since the plan is silent on it.

REVIEW_PASS
