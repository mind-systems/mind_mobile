# Plan: Update `lib/Core/Grpc/ModuleStateChannel.dart`

## Context

Migrate `ModuleStateChannel.dart` from the old `live.proto` generated stubs to the new `module_state.proto` stubs, updating the import, client class, RPC method, message types, and the renamed `moduleSessionId` field. This is part of Phase 8.2 (proto contract rename).

## Status: Already Complete

All tasks in this plan were already implemented before the plan was created. A codebase-wide search confirms zero remaining references to the old identifiers (`liveSessionId`, `live.pbgrpc.dart`, `telemetry.pbgrpc.dart`, `LiveServiceClient`, `TelemetryServiceClient`, `LiveRequest`, `LiveResponse`).

No implementation is needed — mark Phase 8.2 tasks in the roadmap as done.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Update proto references

- [x] **Task 1: Replace proto import and client type**
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Replace `import 'package:mind/Core/Grpc/generated/live.pbgrpc.dart' as proto` with `import 'package:mind/Core/Grpc/generated/module_state.pbgrpc.dart' as proto`. Replace the field type and constructor parameter `proto.LiveServiceClient` with `proto.ModuleStateServiceClient` (field `_moduleStateService` and named constructor param `moduleStateService`).

- [x] **Task 2: Replace RPC call and message types**
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  In `_openSessionStream()`, replace `_moduleStateService.liveSession(...)` with `_moduleStateService.trackActivity(...)`. Replace all occurrences of `proto.LiveRequest` with `proto.SessionRequest` and `proto.LiveResponse` with `proto.SessionResponse`. Replace `proto.LiveResponse_Event` enum references (`.sessionState`, `.sessionError`, `.notSet`) with `proto.SessionResponse_Event`. The stream variable types `StreamSubscription<proto.LiveResponse>` and `StreamController<proto.LiveRequest>` become `StreamSubscription<proto.SessionResponse>` and `StreamController<proto.SessionRequest>`.

- [x] **Task 3: Rename `liveSessionId` field access**
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  In `_processProtoEvent`, replace `event.liveSessionId` with `event.moduleSessionId` (the `SessionStateEvent` proto field was renamed from `live_session_id` to `module_session_id`). Update the corresponding `ModuleState(...)` and `ModuleSessionStarted(...)` constructor calls to pass the value as `moduleSessionId:`.
