# Plan: Add `meditation` to `ActivityType` + map to proto

## Context
Extend the domain `ActivityType` enum with a `meditation` value and map it to the generated `proto.ActivityType.MEDITATION` so meditation sessions can be tracked over the module-state gRPC channel.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Extend domain enum and proto mapping

- [x] **Task 1: Add `meditation` to `ActivityType` enum**
  Files: `lib/Core/Grpc/ActivityType.dart`
  Change `enum ActivityType { breath }` to `enum ActivityType { breath, meditation }`.

- [x] **Task 2: Map `meditation` to proto in `_mapActivityType`** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  In the `_mapActivityType` switch (around line 194), add a new case after the existing `breath` case:
  ```dart
  case ActivityType.meditation:
    return proto.ActivityType.MEDITATION;
  ```
  Prerequisite: the generated proto stub (`lib/Core/Grpc/generated/module_state.pb*.dart`) must already expose `proto.ActivityType.MEDITATION` (delivered by the previous roadmap task). The exhaustive switch will not compile until both the enum value and the proto constant exist.
