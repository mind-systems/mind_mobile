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

- [ ] **Implement `lib/User/AuthGrpcApi.dart`** — update `IAuthApi` signatures to match proto shapes; create `AuthGrpcApi` implementing `IAuthApi` via `GrpcClient.authStub`; wire in `App.dart`
- [ ] **Delete AuthApi.dart** — remove `lib/Core/Api/AuthApi.dart` after AuthGrpcApi is wired

### 2.6 Replace BreathSessionApi with generated stub

- [ ] **Implement `lib/BreathModule/Core/BreathSessionGrpcApi.dart`** — update `IBreathSessionApi` signatures if proto shapes differ; create `BreathSessionGrpcApi` via `GrpcClient.breathSessionsStub`; wire in `BreathModule.dart`
- [ ] **Delete BreathSessionApi.dart** — remove `lib/Core/Api/BreathSessionApi.dart` after BreathSessionGrpcApi is wired

### 2.7 Replace UserApi with generated stub

- [ ] **Implement `lib/User/UserGrpcApi.dart`** — implements `IUserApi` via `GrpcClient.usersStub`; wire in `App.dart`
- [ ] **Delete UserApi.dart** — remove `lib/Core/Api/UserApi.dart` after UserGrpcApi is wired

### 2.8 Replace SyncApi with generated stub

- [ ] **Implement `lib/Core/Sync/SyncGrpcApi.dart`** — update `ISyncApi.getChanges(cursor, limit)` signature if needed; create `SyncGrpcApi` via `GrpcClient.syncStub`; wire in `App.dart`
- [ ] **Delete SyncApi.dart** — remove `lib/Core/Api/SyncApi.dart` after SyncGrpcApi is wired

### 2.9 Replace DeviceApi with generated stub

- [ ] **Implement `lib/Core/Device/DeviceGrpcApi.dart`** — implements device interface (or inline if no interface exists) via `GrpcClient.deviceStub`; wire in `App.dart`
- [ ] **Delete DeviceApi.dart** — remove `lib/Core/Api/DeviceApi.dart` after DeviceGrpcApi is wired

### 2.10 Replace PersonalAccessTokenApi with generated stub

- [ ] **Implement `lib/McpModule/PersonalAccessTokenGrpcApi.dart`** — update `IPersonalAccessTokenApi` signatures if needed; implements via `GrpcClient.authStub` (PAT methods are in `auth.proto`); wire in `App.dart`
- [ ] **Delete PersonalAccessTokenApi.dart** — remove `lib/Core/Api/PersonalAccessTokenApi.dart` after PersonalAccessTokenGrpcApi is wired

### 2.11 Replace StatsApi with generated stub

- [ ] **Implement `lib/User/StatsGrpcApi.dart`** — implements stats interface (or inline if no interface exists) via `GrpcClient.statsStub`; maps `GetStatsResponse` to domain model; wire in `App.dart` or the relevant notifier
- [ ] **Delete StatsApi.dart** — remove old `StatsApi.dart` if it exists, after StatsGrpcApi is wired

---

## Phase 3 — Sync: Socket.io → gRPC Streaming

### 3.4 Replace Socket.io sync push

- [ ] **Create SyncGrpcListener** — create `lib/Core/Sync/SyncGrpcListener.dart` and wire in `App.dart`; replace Socket.io `sync:changed` listener with a gRPC server-streaming call to `WatchChanges`; on each received `ChangeEvent`, call `SyncEngine.onChangeEvent()`; replace `SyncSocketListener` with `SyncGrpcListener` in `App.dart`

### 3.5 Replace LiveSocketService

> Reconnect strategy: `package:grpc` does not reconnect closed streams automatically. On `GrpcError` with retryable status, wait with exponential back-off and re-open the RPC call. `interceptStreaming` cannot be async — token must be available synchronously (guaranteed if streaming is only opened after a successful unary call).

- [ ] **Create `lib/Core/Grpc/LiveSessionGrpcService.dart`** — holds `_liveCall` (bidi), `_telemetryCall` (bidi), `_syncCall` (server-streaming); implements reconnect with exponential back-off; maps domain events to `LiveRequest` proto messages; drives existing `BehaviorSubject<SocketConnectionState>` and stream controllers
- [ ] **Update `BreathTelemetryService.sendSample()`** — when mapping to `TelemetryData` proto, add `module_id: "breath"` and `instruction_type: "breath_phase"`; currently mobile sends only `{ phase, durationMs }` with no type discriminator (`lib/BreathModule/Core/BreathTelemetryService.dart`)
- [ ] **Replace `SocketConnectionCoordinator.dart`** — wire lifecycle (connect/disconnect/reconnect) to `LiveSessionGrpcService`; replace Socket.io connection state handling
- [ ] **Update `LiveSessionCoordinator.dart` in `packages/breath_module/`** — replace calls to `ILiveSocketService` methods with equivalent gRPC stream sends if interface changes

### 3.6 Remove Socket.io infrastructure (mobile side)

- [ ] **Delete Socket.io client files and remove dependency** — delete `lib/Core/Socket/LiveSocketService.dart`, `ILiveSocketService.dart`, `SocketConnectionState.dart`, `SocketConnectionCoordinator.dart`, `SocketDebugOverlay.dart`, `SyncSocketListener.dart`; run `flutter pub remove socket_io_client`

---

## Phase 4 — Cleanup

### 4.3 Remove Dio from mobile

- [ ] **Delete Dio infrastructure** — delete `lib/Core/Api/HttpClient.dart` and `lib/Core/Api/AuthInterceptor.dart` (only after all API files in 2.5–2.11 are deleted and `GrpcAuthInterceptor` is active)
- [ ] **Remove Dio and verify** — `flutter pub remove dio`; confirm no remaining `package:dio` imports with `grep -r "package:dio" lib/`

---

## Completed

| Milestone | Date |
|-----------|------|
