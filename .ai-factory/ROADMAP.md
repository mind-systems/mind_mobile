# Mind Mobile — Roadmap

## Phase 2 — Mobile gRPC Client

### 2.1 Install Flutter gRPC packages

- [x] **Add gRPC packages** — `flutter pub add grpc protobuf`

### 2.2 protoc codegen setup

- [x] **Install toolchain** — install `protoc` (document exact version in `mind_mobile/proto/README.md`) and `dart pub global activate protoc_plugin`
- [x] **Copy proto files** — create `mind_mobile/proto/` and copy all `.proto` files from `mind_api/proto/` (no symlinks — copy explicitly; `mind_api/proto/` is the source of truth)
- [x] **Create `scripts/gen_proto.sh`** — runs `protoc` with `--dart_out=grpc:lib/Core/Grpc/generated/` for each `.proto` file; document command in `mind_mobile/CLAUDE.md`
- [x] **Run codegen** — execute script, commit generated files to `lib/Core/Grpc/generated/`

### 2.3 Create GrpcClient

- [x] **Create `lib/Core/Grpc/GrpcClient.dart`** — singleton class that holds a `ClientChannel` (host + port from `Environment.dart`); exposes lazy-initialized stubs for each service (`AuthServiceClient`, `BreathSessionsServiceClient`, etc.); expose a `shutdown()` method that calls `channel.shutdown()` — call it on logout and when the app is terminated (`WidgetsBindingObserver.didChangeAppLifecycleState`)
- [x] **Update `lib/Core/Environment.dart` (and `.example.dart`)** — add `grpcHost` and `grpcPort` fields; add dev/prod values

### 2.4 Replace AuthInterceptor with gRPC ClientInterceptor

> Key decisions: token read from `FlutterSecureStorage` directly (not `UserNotifier`); `interceptStreaming` cannot be async — streaming calls must be opened only after at least one successful unary call has already loaded the token; `StatusCode.unauthenticated` (16) is the correct code to intercept.

- [x] **Create `lib/Core/Grpc/GrpcAuthInterceptor.dart`** — implements `ClientInterceptor`; overrides `interceptUnary` (async, reads token from `FlutterSecureStorage`, merges `CallOptions`, catches `GrpcError` code 16 → `LogoutNotifier.triggerLogout()`) and `interceptStreaming` (sync, attaches token via pre-built options, pipes errors to same handler)
- [x] **Instantiate once in `App._init()`** — pass same instance to every stub in `GrpcClient`; inject `FlutterSecureStorage` and `LogoutNotifier`
- [x] **Remove `lib/Core/Api/AuthInterceptor.dart`** — only after all Dio-based APIs are replaced (do last in this phase)

### 2.5 Replace AuthApi with generated stub

> **Prerequisite:** 2.4 complete — `GrpcAuthInterceptor` must be wired before any API stub is used.

- [x] **Implement `lib/User/AuthGrpcApi.dart`** — update `IAuthApi` signatures to match proto shapes; create `AuthGrpcApi` implementing `IAuthApi` via `GrpcClient.authStub`; wire in `App.dart`
- [x] **Delete AuthApi.dart** — remove `lib/Core/Api/AuthApi.dart` after AuthGrpcApi is wired

### 2.6 Replace BreathSessionApi with generated stub

- [x] **Implement `lib/BreathModule/Core/BreathSessionGrpcApi.dart`** — update `IBreathSessionApi` signatures if proto shapes differ; create `BreathSessionGrpcApi` via `GrpcClient.breathSessionsStub`; wire in `BreathModule.dart`
- [x] **Delete BreathSessionApi.dart** — remove `lib/Core/Api/BreathSessionApi.dart` after BreathSessionGrpcApi is wired

### 2.7 Replace UserApi with generated stub

- [x] **Implement `lib/User/UserGrpcApi.dart`** — implements `IUserApi` via `GrpcClient.usersStub`; wire in `App.dart`
- [x] **Delete UserApi.dart** — remove `lib/Core/Api/UserApi.dart` after UserGrpcApi is wired

### 2.8 Replace SyncApi with generated stub

- [x] **Implement `lib/Core/Sync/SyncGrpcApi.dart`** — update `ISyncApi.getChanges(cursor, limit)` signature if needed; create `SyncGrpcApi` via `GrpcClient.syncStub`; wire in `App.dart`
- [x] **Delete SyncApi.dart** — remove `lib/Core/Api/SyncApi.dart` after SyncGrpcApi is wired

### 2.9 Replace DeviceApi with generated stub

- [x] **Implement `lib/Core/Device/DeviceGrpcApi.dart`** — implements device interface (or inline if no interface exists) via `GrpcClient.deviceStub`; wire in `App.dart`
- [x] **Delete DeviceApi.dart** — remove `lib/Core/Api/DeviceApi.dart` after DeviceGrpcApi is wired

### 2.10 Replace PersonalAccessTokenApi with generated stub

- [x] **Implement `lib/McpModule/PersonalAccessTokenGrpcApi.dart`** — update `IPersonalAccessTokenApi` signatures if needed; implements via `GrpcClient.authStub` (PAT methods are in `auth.proto`); wire in `App.dart`
- [x] **Delete PersonalAccessTokenApi.dart** — remove `lib/Core/Api/PersonalAccessTokenApi.dart` after PersonalAccessTokenGrpcApi is wired

### 2.11 Replace StatsApi with generated stub

- [x] **Implement `lib/User/StatsGrpcApi.dart`** — implements stats interface (or inline if no interface exists) via `GrpcClient.statsStub`; maps `GetStatsResponse` to domain model; wire in `App.dart` or the relevant notifier
- [x] **Delete StatsApi.dart** — remove old `StatsApi.dart` if it exists, after StatsGrpcApi is wired

---

## Phase 3 — Sync: Socket.io → gRPC Streaming

### 3.4 Replace Socket.io sync push

- [x] **Create SyncGrpcListener** — create `lib/Core/Sync/SyncGrpcListener.dart` and wire in `App.dart`; replace Socket.io `sync:changed` listener with a gRPC server-streaming call to `WatchChanges`; on each received `ChangeEvent`, call `SyncEngine.onChangeEvent()`; replace `SyncSocketListener` with `SyncGrpcListener` in `App.dart`

### 3.5 Replace LiveSocketService

> Reconnect strategy: `package:grpc` does not reconnect closed streams automatically. On `GrpcError` with retryable status, wait with exponential back-off and re-open the RPC call. `interceptStreaming` cannot be async — token must be available synchronously (guaranteed if streaming is only opened after a successful unary call).

- [x] **Create `lib/Core/Grpc/LiveSessionGrpcService.dart`** — holds `_liveCall` (bidi), `_telemetryCall` (bidi), `_syncCall` (server-streaming); implements reconnect with exponential back-off; maps domain events to `LiveRequest` proto messages; drives existing `BehaviorSubject<SocketConnectionState>` and stream controllers
- [x] **Update `BreathTelemetryService.sendSample()`** — when mapping to `TelemetryData` proto, add `module_id: "breath"` and `instruction_type: "breath_phase"`; currently mobile sends only `{ phase, durationMs }` with no type discriminator (`lib/BreathModule/Core/BreathTelemetryService.dart`)
- [x] **Replace `SocketConnectionCoordinator.dart`** — wire lifecycle (connect/disconnect/reconnect) to `LiveSessionGrpcService`; replace Socket.io connection state handling
- [x] **Update `LiveSessionCoordinator.dart` in `packages/breath_module/`** — replace calls to `ILiveSocketService` methods with equivalent gRPC stream sends if interface changes

### 3.6 Remove Socket.io infrastructure (mobile side)

- [x] **Delete Socket.io client files and remove dependency** — delete `lib/Core/Socket/LiveSocketService.dart`, `ILiveSocketService.dart`, `SocketConnectionState.dart`, `SocketConnectionCoordinator.dart`, `SocketDebugOverlay.dart`, `SyncSocketListener.dart`; run `flutter pub remove socket_io_client`

---

## Phase 4 — Cleanup

### 4.3 Remove Dio from mobile

- [x] **Delete Dio infrastructure** — delete `lib/Core/Api/HttpClient.dart` and `lib/Core/Api/AuthInterceptor.dart` (only after all API files in 2.5–2.11 are deleted and `GrpcAuthInterceptor` is active)
- [x] **Remove Dio and verify** — `flutter pub remove dio`; confirm no remaining `package:dio` imports with `grep -r "package:dio" lib/`

---

## Phase 5 — HTTP Client

### 5.1 Restore Dio as general-purpose HTTP client

- [x] **Restore `lib/Core/Api/HttpClient.dart`** — re-add from `dev` branch (commit `bb04376`); wraps Dio with `get`, `post`, `patch`, `put`, `delete` methods and structured error handling via `ApiException`; restore `lib/Core/Api/Models/ApiExeption.dart`; `flutter pub add dio`

---

## Phase 6 — ILiveSocketService cleanup

### 6.1 Drop dead `syncChangedEvents` from the interface

- [x] **Remove `syncChangedEvents` from `ILiveSocketService`** — the method is a stub returning `Stream.empty()` in `LiveSessionGrpcService`; sync is now handled entirely by `SyncGrpcListener`; remove the getter from the abstract interface and delete the stub implementation

### 6.2 Replace `emitLive(String)` with typed gRPC commands

- [x] **Replace `emitLive(String event, Map?)` with typed methods in `ILiveSocketService`** — the string-event API is a Socket.io leftover; replace with explicit methods: `sendActivityStart({required ActivityType type, String? refId})`, `sendActivityEnd()`, `sendActivityStop()`, `sendActivityPause()`, `sendActivityResume()`; update `LiveSessionGrpcService` to implement typed methods (remove the string-switch); update `LiveBreathSessionNotifier` to call typed methods

### 6.3 Strip all Socket.io naming leftovers

- [x] **Rename `*GrpcApi` → `*Api` classes and files** — `AuthGrpcApi`, `UserGrpcApi`, `BreathSessionGrpcApi`, `SyncGrpcApi`, `DeviceGrpcApi`, `PersonalAccessTokenGrpcApi`, `StatsGrpcApi`; update wiring in `App.dart` and `BreathModule.dart`
- [x] **Rename `ILiveSocketService` → `ILiveSessionService` and all `liveSocket*` variables** — rename class and file; update imports in `LiveSessionGrpcService.dart`, `LiveBreathSessionNotifier.dart`, test file; rename field `_liveSocketService` → `_liveSessionService` and param `liveSocketService` → `liveSessionService` in `App.dart`, `LiveBreathSessionNotifier.dart`, `BreathTelemetryService.dart`; rename `FakeLiveSocketService` → `FakeLiveSessionService` in test

---

## Phase 7 — Live Session Architecture Refactor

### 7.1 Extract GrpcConnectionManager

- [x] **Extract `GrpcConnectionManager` from `LiveSessionGrpcService`** — pull out connect / disconnect / backoff / auth+connectivity+resume listeners into a standalone class; expose `Stream<ConnectionState>` that other classes subscribe to; rename `SocketConnectionState` → `ConnectionState` (file + enum), scope it to `lib/Core/Grpc/`

### 7.2 Create ModuleStateChannel

- [x] **Create `ModuleStateChannel` — activity lifecycle over live.proto** — owns the `LiveService/LiveSession` bidi stream; absorbs `LiveBreathSessionNotifier` pending-guard logic and Map→typed-state mapping; exposes typed `Stream<ModuleStateEvent>`; subscribes to `GrpcConnectionManager.connectionState`; receives typed proto `SessionStateEvent` directly (no `Map<String, dynamic>`)
- [x] **Delete `LiveBreathSessionNotifier`** — fully absorbed into `ModuleStateChannel`; update all usages

### 7.3 Create ModuleInstructionStream

- [x] **Create `ModuleInstructionStream` — instruction samples over telemetry.proto** — owns the `TelemetryService/StreamTelemetry` bidi stream; subscribes to `GrpcConnectionManager.connectionState`; exposes `emit(InstructionSample)` and `Stream<InstructionAck>`
- [x] **Rename `TelemetryBuffer` → `InstructionBuffer`** — file + class rename; update all usages

### 7.4 Delete LiveSessionGrpcService

- [x] **Delete `LiveSessionGrpcService`** — fully replaced by `GrpcConnectionManager` + `ModuleStateChannel` + `ModuleInstructionStream`; remove `ILiveSessionService` interface; update wiring in `App.dart`

### 7.5 Create BreathModuleStateChannel

- [x] **Create `BreathModuleStateChannel` in `lib/BreathModule/Core/`** — injects `ModuleStateChannel`; subscribes to `BreathSessionState` stream; translates state transitions → `channel.start(ActivityType.breath, refId)` / `channel.pause()` / `channel.resume()` / `channel.end()`; reads `liveSessionId` from channel events and exposes it for the instruction stream
- [x] **Delete `LiveBreathSessionService` and `LiveBreathSessionCoordinator`** — absorbed into `BreathModuleStateChannel`; remove interface files; update `BreathModule.dart` wiring

### 7.6 Create BreathModuleInstructionStream

- [x] **Rename `BreathTelemetryService` → `BreathModuleInstructionStream`** — file + class rename; injects `ModuleInstructionStream` instead of `ILiveSessionService`; on breath phase change emits `InstructionSample(phase, durationMs)`; rate limiting and `InstructionBuffer` stay as-is
- [x] **Remove `IBreathTelemetryService` interface** — replace with `BreathModuleInstructionStream` concrete class at the wiring point; update `BreathModule.dart`

### 7.7 Update module boundary interfaces

- [x] **Update `ILiveBreathSessionService` → remove or replace** — `BreathModuleStateChannel` no longer needs this interface (it owns the channel directly); clean up `packages/breath_module` interface files that referenced live session service and telemetry service; update `BreathModule.dart` assembly point

---

---

## Phase 8 — Rename: Proto Contract Update

### 8.1 Copy updated proto files and regenerate stubs

- [x] **Copy proto files to mind_mobile** — copy `mind_api/proto/module_state.proto` to `mind_mobile/proto/` replacing `mind_mobile/proto/live.proto`; copy `mind_api/proto/module_instruction_stream.proto` to `mind_mobile/proto/` replacing `mind_mobile/proto/telemetry.proto`; delete the old `live.proto` and `telemetry.proto` from `mind_mobile/proto/`
- [x] **Regenerate Dart stubs in mind_mobile** — run `bash scripts/gen_proto.sh` from the `mind_mobile/` root; verify that `lib/Core/Grpc/generated/` contains new `module_state.pb.dart`, `module_state.pbgrpc.dart`, `module_instruction_stream.pb.dart`, `module_instruction_stream.pbgrpc.dart` and that the old `live.pb.dart`, `live.pbgrpc.dart`, `telemetry.pb.dart`, `telemetry.pbgrpc.dart` are gone (the script wipes and recreates the output directory)

### 8.2 Update Dart code in mind_mobile

- [x] **Update `lib/Core/Grpc/ModuleStateChannel.dart`** — replace `import 'package:mind/Core/Grpc/generated/live.pbgrpc.dart' as proto` with the import for the new `module_state.pbgrpc.dart`; replace `proto.LiveServiceClient` with `proto.ModuleStateServiceClient`; replace the `liveSession` RPC call with the renamed RPC on the new client; replace all references to `proto.LiveRequest`, `proto.LiveResponse`, `proto.LiveResponse_Event` with the equivalents from the new generated file; replace `event.liveSessionId` with `event.moduleSessionId` (field renamed in `SessionStateEvent`)
- [x] **Update `lib/Core/Grpc/ModuleState.dart`** — rename field `liveSessionId` → `moduleSessionId` in the `ModuleState` class definition, constructor parameter, `ModuleState.initial()` factory, and the `_state.add(ModuleState(liveSessionId: ...))` call sites in `ModuleStateChannel`
- [x] **Update `lib/Core/Grpc/ModuleStateEvent.dart`** — rename field `liveSessionId` → `moduleSessionId` in `ModuleSessionStarted` and its constructor parameter
- [x] **Update `lib/Core/Grpc/ModuleInstructionStream.dart`** — replace `import 'package:mind/Core/Grpc/generated/telemetry.pbgrpc.dart'` with the import for `module_instruction_stream.pbgrpc.dart`; replace `TelemetryServiceClient` with `ModuleInstructionStreamServiceClient`; replace `TelemetryData`, `TelemetryResponse`, `TelemetryResponse_Event`, `TelemetryAck` with the equivalents from the new generated file
- [x] **Update `lib/BreathModule/Core/BreathModuleStateChannel.dart`** — rename private field `_liveSessionId` → `_moduleSessionId` and its getter `liveSessionId` → `moduleSessionId`; update the `_channelSub` listener that reads `moduleState.liveSessionId` → `moduleState.moduleSessionId`; update the `_flushPending` and `_handleTelemetry` call sites that pass `liveId` (derived from `_liveSessionId`)

---

## Completed

| Milestone | Date |
|-----------|------|
| 7.7 Update module boundary interfaces (`ILiveBreathSessionService` removed, `BreathModuleStateChannel` owns channel directly) | 2026-03-28 |
