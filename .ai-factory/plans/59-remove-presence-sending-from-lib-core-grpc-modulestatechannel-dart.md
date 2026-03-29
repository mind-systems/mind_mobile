# Plan: Remove presence sending from ModuleStateChannel

## Context

Delete any calls that send a `PresenceCmd` and remove imports of `PresenceCmd` or `PresenceState` from `ModuleStateChannel.dart`. This is the second item in Phase 9.2 of the roadmap.

**Finding:** After plan 58 synced the proto files and regenerated stubs, `PresenceCmd` and `PresenceState` no longer exist in any generated Dart file. Additionally, `ModuleStateChannel.dart` never sent a `PresenceCmd` or imported `PresenceState` — the mobile client was not using these types prior to the proto sync either. No hand-written Dart files under `lib/` reference these types.

This milestone requires no code changes. It is a verification-only task.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Verify and close

- [x] **Task 1: Confirm no PresenceCmd/PresenceState references remain**
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`, `lib/Core/Grpc/generated/module_state.pb.dart`, `lib/Core/Grpc/generated/module_state.pbenum.dart`, `lib/Core/Grpc/generated/module_state.pbjson.dart`
  Grep the entire `lib/` tree for `PresenceCmd` and `PresenceState` (case-sensitive). Confirm zero matches. Grep `lib/Core/Grpc/generated/module_state.pb.dart` for `presence` (case-insensitive) to confirm no leftover field accessors. No code changes required — this is a verification step to close the roadmap item.
