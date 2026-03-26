# Plan: Implement DeviceGrpcApi

## Context
Migrate the device ping from REST (`DeviceApi` via `HttpClient`) to gRPC (`DeviceGrpcApi` via `GrpcClient.deviceService`), then delete the old REST class. The gRPC stubs are already generated (`DeviceServiceClient`, `PingRequest`); the stub is wired on `GrpcClient` but unused. Since no `IDeviceApi` interface exists, `DeviceGrpcApi` replaces `DeviceApi` as a concrete class and `DeviceRepository` is updated to accept the new type.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Implement and wire

- [x] **Task 1: Create `DeviceGrpcApi`**
  Files: `lib/Device/DeviceGrpcApi.dart` (new)
  Create a new file at `lib/Device/DeviceGrpcApi.dart` (next to `DeviceRepository.dart`, following the established pattern where gRPC API classes live near their repository — e.g. `lib/User/AuthGrpcApi.dart`, `lib/BreathModule/Core/BreathSessionGrpcApi.dart`, `lib/Core/Sync/SyncGrpcApi.dart`). Follow the pattern used by `SyncGrpcApi` and `BreathSessionGrpcApi`:
  - Import the generated proto files with an alias: `import 'package:mind/Core/Grpc/generated/device.pb.dart' as proto;` and `import 'package:mind/Core/Grpc/generated/device.pbgrpc.dart' show DeviceServiceClient;`.
  - Import `DevicePingRequest` from `lib/Core/Api/Models/DevicePingRequest.dart`.
  - Constructor takes `DeviceServiceClient` as a positional parameter, stored in a private `_deviceService` field.
  - Single method: `Future<void> ping(DevicePingRequest request) async` — builds a `proto.PingRequest` from the `DevicePingRequest` fields (all 11 fields: `installationId`, `platform`, `osVersion`, `locale`, `timezone`, `screenWidth`, `screenHeight`, `appVersion`, `buildNumber`, `model`, `manufacturer`) and calls `await _deviceService.ping(protoRequest)`. Return type is `void` since `PingResponse` is empty.
  - No try/catch — errors propagate to the caller (matches all other GrpcApi implementations; `DeviceRepository` already wraps the call in its own catch).

- [x] **Task 2: Update `DeviceRepository` to use `DeviceGrpcApi`**
  Files: `lib/Device/DeviceRepository.dart`
  Change the import from `DeviceApi` to `DeviceGrpcApi` (now a sibling file in `lib/Device/`). Update the constructor parameter type and the private field type from `DeviceApi` to `DeviceGrpcApi`. The method call (`_api.ping(request)`) stays the same since `DeviceGrpcApi` exposes the same `ping(DevicePingRequest)` signature.

- [x] **Task 3: Wire `DeviceGrpcApi` in `App.dart`**
  Files: `lib/Core/App.dart`
  Replace the REST wiring at line 134 (`final deviceApi = DeviceApi(httpClient)`) with `final deviceApi = DeviceGrpcApi(grpcClient.deviceService)`. Update the import from `DeviceApi` to `DeviceGrpcApi`. The `DeviceRepository` constructor call on line 135 stays unchanged (still `api: deviceApi`). Keep the single-line style with no trailing commas (App.dart convention). Remove the `DeviceApi` import if it becomes unused.

- [x] **Task 4: Delete `DeviceApi.dart`**
  Files: `lib/Core/Api/DeviceApi.dart` (delete)
  Delete `lib/Core/Api/DeviceApi.dart` — it is now dead code with no remaining imports. Verify no file still imports `package:mind/Core/Api/DeviceApi.dart` before deleting.
