# proto/

This directory contains `.proto` files that define the gRPC service contracts used by the mobile app.

## Source of truth

`.proto` files originate from `mind_api/proto/` — that is the single source of truth. **Never edit proto files in this repo directly.** When `mind_api/proto/` changes, copy the updated files into this directory and regenerate the Dart stubs (see *Codegen* below).

## Prerequisites

Install the protobuf compiler and activate the Dart protoc plugin before running codegen.

```bash
# 1. Install protoc (macOS)
brew install protobuf
# Expected: protoc --version → libprotoc 34.0

# 2. Activate the Dart plugin at the pinned version
dart pub global activate protoc_plugin 25.0.0
# Expected: dart pub global list → protoc_plugin 25.0.0
```

## Version compatibility

| Tool | Pinned version |
|------|----------------|
| `protoc` | `libprotoc 34.0` |
| `protoc_plugin` (Dart) | `25.0.0` |
| `protobuf` runtime (pubspec) | `^6.0.0` (currently `6.0.0`) |

`protoc_plugin 25.0.0` requires the `protobuf ^6.0.0` runtime package. Keep these versions in sync — upgrading either without the other will cause codegen or runtime errors.

## Codegen

The codegen script (`scripts/gen_proto.sh`) will be added in a follow-up plan (roadmap item 2.2). Once available, run it to regenerate Dart stubs from the `.proto` files in this directory.
