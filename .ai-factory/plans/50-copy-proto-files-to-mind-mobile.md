# Plan: Copy proto files to mind_mobile

## Context
Replace the old `live.proto` and `telemetry.proto` in `mind_mobile/proto/` with the renamed `module_state.proto` and `module_instruction_stream.proto` from `mind_api/proto/`, regenerate Dart stubs, and update all consuming Dart files to use the new generated types and consistent naming.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Replace proto files and regenerate stubs

- [x] **Task 1: Copy new proto files and delete old ones**
  Files: `proto/module_state.proto`, `proto/module_instruction_stream.proto`, `proto/live.proto`, `proto/telemetry.proto`
  Copy `mind_api/proto/module_state.proto` to `mind_mobile/proto/module_state.proto`. Copy `mind_api/proto/module_instruction_stream.proto` to `mind_mobile/proto/module_instruction_stream.proto`. Delete `mind_mobile/proto/live.proto` and `mind_mobile/proto/telemetry.proto`.

- [x] **Task 2: Regenerate Dart gRPC stubs** (depends on Task 1)
  Files: `lib/Core/Grpc/generated/` (entire directory)
  Run `./scripts/gen_proto.sh` from the `mind_mobile` root. The script wipes `lib/Core/Grpc/generated/` and regenerates all stubs in one pass. This produces `module_state.pb.dart`, `module_state.pbenum.dart`, `module_state.pbgrpc.dart`, `module_state.pbjson.dart` and the corresponding `module_instruction_stream.*` files, replacing the old `live.*` and `telemetry.*` stubs.

### Phase 2: Update domain models

- [x] **Task 3: Rename `liveSessionId` → `moduleSessionId` in ModuleState** (depends on Task 2)
  Files: `lib/Core/Grpc/ModuleState.dart`
  Rename the field `liveSessionId` → `moduleSessionId` in the `ModuleState` class: the field declaration (line 4), the constructor parameter (line 8), and the `ModuleState.initial()` factory (line 11 — `liveSessionId: null` → `moduleSessionId: null`).

- [x] **Task 4: Rename `liveSessionId` → `moduleSessionId` in ModuleStateEvent** (depends on Task 2)
  Files: `lib/Core/Grpc/ModuleStateEvent.dart`
  Rename the field `liveSessionId` → `moduleSessionId` in `ModuleSessionStarted`: field declaration (line 4) and constructor parameter (line 5).

### Phase 3: Update gRPC channel consumers

- [x] **Task 5: Update GrpcClient imports and service fields** (depends on Task 2)
  Files: `lib/Core/Grpc/GrpcClient.dart`
  Replace `import '…/live.pbgrpc.dart'` with `import '…/module_state.pbgrpc.dart'`. Replace `import '…/telemetry.pbgrpc.dart'` with `import '…/module_instruction_stream.pbgrpc.dart'`. Rename the `late final` service fields:
  - `LiveServiceClient` → `ModuleStateServiceClient`, field name `liveService` → `moduleStateService`
  - `TelemetryServiceClient` → `ModuleInstructionStreamServiceClient`, field name `telemetryService` → `instructionStreamService`

- [x] **Task 6: Update ModuleStateChannel to use new proto types** (depends on Tasks 3, 4)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Change import from `live.pbgrpc.dart` to `module_state.pbgrpc.dart`. Update all proto type references:
  - `proto.LiveServiceClient` → `proto.ModuleStateServiceClient`
  - `proto.LiveResponse` → `proto.SessionResponse`
  - `proto.LiveResponse_Event` → `proto.SessionResponse_Event`
  - `proto.LiveRequest` → `proto.SessionRequest`
  - Constructor parameter type `proto.LiveServiceClient liveService` → `proto.ModuleStateServiceClient moduleStateService` (rename field `_liveService` → `_moduleStateService`)
  - `_liveService.liveSession(…)` → `_moduleStateService.trackActivity(…)`
  - Rename local variables/subs: `_liveSub`/`_liveSink` → `_sessionSub`/`_sessionSink` (and update all usages)
  - Rename methods: `_openLiveStream`/`_closeLiveStream`/`_sendLiveRequest` → `_openSessionStream`/`_closeSessionStream`/`_sendSessionRequest`
  - `event.liveSessionId` → `event.moduleSessionId` (proto field renamed)
  - Rename the local variable that captures the proto field: `final liveSessionId = event.liveSessionId` → `final moduleSessionId = event.moduleSessionId` (line 117), and update its usage at `ModuleState(liveSessionId:` → `ModuleState(moduleSessionId: moduleSessionId, …)` (line 122) and `ModuleSessionStarted(liveSessionId:` → `ModuleSessionStarted(moduleSessionId: moduleSessionId)` (line 124)

- [x] **Task 7: Update ModuleInstructionStream to use new proto types** (depends on Task 2)
  Files: `lib/Core/Grpc/ModuleInstructionStream.dart`
  Change import from `telemetry.pbgrpc.dart` to `module_instruction_stream.pbgrpc.dart`. Update all proto type references:
  - `TelemetryServiceClient` → `ModuleInstructionStreamServiceClient`
  - `TelemetryResponse` → `StreamResponse`
  - `TelemetryResponse_Event` → `StreamResponse_Event`
  - `TelemetryData` → `StreamSample`
  - `TelemetryAck` → `StreamAck` (used when destructuring `.ack`)
  - Constructor parameter `TelemetryServiceClient telemetryService` → `ModuleInstructionStreamServiceClient instructionStreamService` (rename field `_telemetryService` → `_instructionStreamService`)
  - `_telemetryService.streamTelemetry(…)` → `_instructionStreamService.streamData(…)`
  - Rename local variables: `_telemetrySub` → `_streamSub`, `_telemetrySink` → `_streamSink` (update all usages)
  - Rename `_toProto` return type from `TelemetryData` to `StreamSample` and use `StreamSample(…)` constructor

- [x] **Task 8: Update BreathModuleStateChannel field renames** (depends on Tasks 3, 4)
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  Rename private field `_liveSessionId` → `_moduleSessionId` (line 20) and getter `liveSessionId` → `moduleSessionId` (line 42). Update `_channelSub` listener: `moduleState.liveSessionId` → `moduleState.moduleSessionId` (lines 36-37). Update `_handleTelemetry`: `final liveId = _liveSessionId` → `final sessionId = _moduleSessionId` (line 87) and its null check / usage passing to `_instructionStream.sendSample`. Update `reset()`: `_liveSessionId = null` → `_moduleSessionId = null` (line 111). Update `_flushPending` parameter and local usage — `liveId` → `sessionId` to match the renamed source.

### Phase 4: Update wiring and script

- [x] **Task 9: Update App.dart wiring** (depends on Tasks 5, 6, 7)
  Files: `lib/Core/App.dart`
  Update the two initialization lines (~160-161) to use the renamed GrpcClient fields and constructor parameter names:
  - `liveService: grpcClient.liveService` → `moduleStateService: grpcClient.moduleStateService`
  - `telemetryService: grpcClient.telemetryService` → `instructionStreamService: grpcClient.instructionStreamService`

- [x] **Task 10: Update gen_proto.sh comment** (depends on Task 1)
  Files: `scripts/gen_proto.sh`
  Update the header comment on line 11 — change `telemetry.proto imports google/protobuf/struct.proto` to `module_instruction_stream.proto imports google/protobuf/struct.proto and module_state.proto`.

- [x] **Task 11: Verify compilation** (depends on all previous tasks)
  Files: none (verification step)
  Run `/usr/local/bin/flutter analyze` from the `mind_mobile` root to verify there are no remaining references to old names. If any errors appear, fix the missed references before considering the milestone complete.

## Commit Plan
- **Commit 1** (after tasks 1-2): "Replace live.proto and telemetry.proto with module_state.proto and module_instruction_stream.proto, regenerate stubs"
- **Commit 2** (after tasks 3-11): "Update Dart consumers to use renamed proto types, service clients, and consistent moduleSessionId naming"
