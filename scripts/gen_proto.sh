#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# gen_proto.sh — Generate Dart gRPC stubs from .proto files.
#
# Prerequisites:
#   brew install protobuf           # protoc (libprotoc 34.0)
#   dart pub global activate protoc_plugin 25.0.0
#
# Note: module_instruction_stream.proto imports google/protobuf/struct.proto and module_state.proto
# (well-known and local types). Standard protoc installations via Homebrew include
# google/protobuf on the default include path. If you see "Import not found" errors,
# ensure protoc was installed via `brew install protobuf` and not a stripped-down binary.
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROTO_DIR="proto"
OUT_DIR="lib/Core/Grpc/generated"

cd "$REPO_ROOT"

# Verify required tools are available
if ! command -v protoc &> /dev/null; then
  echo "Error: protoc not found. Install it with: brew install protobuf" >&2
  exit 1
fi

if ! command -v protoc-gen-dart &> /dev/null; then
  echo "Error: protoc-gen-dart not found. Install it with: dart pub global activate protoc_plugin 25.0.0" >&2
  exit 1
fi

# Clean output directory to remove stale files from renamed/removed .proto files
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# Generate protobuf + gRPC service stubs for all .proto files in a single pass
protoc \
  --dart_out=grpc:"$OUT_DIR" \
  -I"$PROTO_DIR" \
  "$PROTO_DIR"/*.proto

echo "Done. Dart stubs written to $OUT_DIR/"
