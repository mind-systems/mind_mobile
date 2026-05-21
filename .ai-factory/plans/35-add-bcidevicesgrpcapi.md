# Plan: Add `BciDevicesGrpcApi`

## Context
Thin Dart wrapper over the generated `BciDevicesServiceClient` exposing the three operations consumed by the upcoming `BciDeviceRepository`: list, register (idempotent), delete. Pure infrastructure adapter — no domain types, no notifiers, no caching.

## Deviation from roadmap directive
ROADMAP.md line 81 says `pass App.shared.grpcClient.channel to constructor`. Plan-review-1 (Critical Issue 1) showed that a `BciDevicesServiceClient` built from a raw channel would skip the auth + logging interceptors (`GrpcAuthInterceptor`, `GrpcLoggingInterceptor` — see `lib/Core/App.dart:121`, `lib/Core/Grpc/GrpcAuthInterceptor.dart`), making every call return `UNAUTHENTICATED` and bypassing the global logout flow. This plan therefore follows the established project pattern: add a `bciDevicesService` late-final on `GrpcClient` (interceptors automatically applied) and inject **that** into `BciDevicesGrpcApi` — identical to `PersonalAccessTokenApi(grpcClient.authService)`. ROADMAP.md line 87 (the next milestone, which references `BciDevicesGrpcApi(grpcClient.channel)`) is updated in Task 4 below so the chain stays consistent.

## Settings
- Testing: no
- Logging: minimal (interceptor-level coverage via `GrpcLoggingInterceptor` is sufficient — no per-method `log()` calls)
- Docs: no

## Tasks

### Phase 1: Register the gRPC service client

- [x] **Task 1: Add `bciDevicesService` to `GrpcClient`**
  Files: `lib/Core/Grpc/GrpcClient.dart`
  Add one new late-final field next to the existing service clients (alphabetical-by-feature, between `authService` and `breathSessionService` works):
  ```dart
  late final bciDevicesService = BciDevicesServiceClient(_channel, interceptors: _interceptors);
  ```
  Add the matching import: `import 'package:mind/Core/Grpc/generated/bci_devices.pbgrpc.dart';`. Do NOT expose `_channel` publicly; do NOT touch other services, `_interceptors`, or `shutdown()`.

### Phase 2: Interface + concrete API wrapper

- [x] **Task 2: Declare `IBciDevicesGrpcApi`** (depends on Task 1)
  Files: `lib/Bci/IBciDevicesGrpcApi.dart`
  New file. Mirrors the project-wide `IXxxApi` convention (`IAuthApi`, `IUserApi`, `IPersonalAccessTokenApi`, `IBreathSessionApi`). Plain `abstract class`:
  ```dart
  abstract class IBciDevicesGrpcApi {
    Future<List<({String id, String serial})>> listDevices();
    Future<({String id, String serial})> register(String serial);
    Future<void> delete(String id);
  }
  ```
  No imports beyond `dart:async` (records are a language feature; no DTO needed at this layer — Plan-review-1 Issue 3 flagged records as acceptable). `register()` returns the device record (id + serial) per Plan-review-1 Issue 7, so the future `BciDeviceManager` can act on the freshly-registered row without a round-trip `list`.

- [x] **Task 3: Implement `BciDevicesGrpcApi`** (depends on Tasks 1 and 2)
  Files: `lib/Bci/BciDevicesGrpcApi.dart`
  New file. `class BciDevicesGrpcApi implements IBciDevicesGrpcApi`.
  - Private field: `final BciDevicesServiceClient _client;`
  - Constructor: `BciDevicesGrpcApi(this._client);` (positional, matches `PersonalAccessTokenApi(this._authService)` in `lib/McpModule/PersonalAccessTokenApi.dart:10`).
  - `Future<List<({String id, String serial})>> listDevices()`:
    - Calls `_client.list(Empty())`.
    - Maps `response.devices` (a `PbList<BciDevice>` already ordered `updated_at DESC` by the server) to `List<({String id, String serial})>` via `.map((d) => (id: d.id, serial: d.serial)).toList()`. Preserve server order — do **not** re-sort.
  - `Future<({String id, String serial})> register(String serial)`:
    - Calls `_client.register(RegisterBciDeviceRequest(serial: serial))`.
    - Returns `(id: response.id, serial: response.serial)`. Server is idempotent on `serial` (existing row reused), so this is safe to call on every successful connect.
  - `Future<void> delete(String id)`:
    - Calls `_client.delete(DeleteBciDeviceRequest(id: id))`.
    - Awaits the `Empty` response and discards it.

  Imports:
  - `package:mind/Bci/IBciDevicesGrpcApi.dart`
  - `package:mind/Core/Grpc/generated/bci_devices.pbgrpc.dart` (re-exports the request/response messages from `bci_devices.pb.dart`, so a single import covers `BciDevicesServiceClient`, `RegisterBciDeviceRequest`, `DeleteBciDeviceRequest`, `ListBciDevicesResponse`, and `BciDevice`).
  - `package:protobuf/well_known_types/google/protobuf/empty.pb.dart` for `Empty`.

  Conventions to follow:
  - File name uses the project's PascalCase pattern (`BciDevicesGrpcApi.dart`) — matches `lib/Bci/NeiryBciProvider.dart` and `lib/McpModule/PersonalAccessTokenApi.dart`.
  - No `StreamController`, no `StreamSubscription`, no `dispose()` (RULES.md: stateless wrappers at this layer).
  - All three methods are `async`/`await`; do not return raw `ResponseFuture`s.
  - Do not catch exceptions — let gRPC errors propagate to the caller; the repository layer (next milestone) owns error policy.

### Phase 3: Roadmap consistency

- [x] **Task 4: Update ROADMAP.md to reference `bciDevicesService` instead of `channel`** (depends on Tasks 1–3)
  Files: `.ai-factory/ROADMAP.md`
  - Line 81 (the current milestone): change `(pass App.shared.grpcClient.channel to constructor)` to `(pass App.shared.grpcClient.bciDevicesService to constructor — the late-final wires up the interceptors automatically)` and update the `register` signature mention from `→ Future<void>` to `→ Future<({String id, String serial})>`.
  - Line 87 (`BciNotifier` milestone): change `BciDevicesGrpcApi(grpcClient.channel)` to `BciDevicesGrpcApi(grpcClient.bciDevicesService)`.
  - Do not mark the current milestone `[x]` here — that happens at `/aif-verify` time.
