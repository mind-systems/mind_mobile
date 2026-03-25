# Plan: Add gRPC packages

## Context
Add the `grpc` and `protobuf` Dart packages as project dependencies so the app can communicate with gRPC services and work with Protocol Buffer messages.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Add dependencies

- [x] **Task 1: Add grpc and protobuf packages**
  Files: `pubspec.yaml`, `pubspec.lock`
  Run `/usr/local/bin/flutter pub add grpc protobuf` from the `mind_mobile/` directory. Verify both packages appear under `dependencies:` in `pubspec.yaml` and that `flutter pub get` resolves without conflicts.
