# Plan: Create `lib/Core/Grpc/GrpcClient.dart`

## Context

Add a singleton gRPC client that owns the `ClientChannel` and exposes lazy-initialized stubs for all 8 generated service clients. Wire it into `App.dart`. No shutdown-on-logout — an idle channel is harmless and the auth interceptor (roadmap §2.4) will handle token rotation. Shutdown on app termination is best-effort via `AppLifecycleService.onDetach`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Environment + GrpcClient

- [x] **Task 1: Add gRPC host, port, and secure flag to Environment**
  Files: `lib/Core/Environment.dart`, `lib/Core/Environment.example.dart`
  Add three fields to `Environment`: `String grpcHost`, `int grpcPort`, `bool grpcSecure`. Add them to the private constructor's named parameters. In `initDev()`, set `grpcHost: 'localhost'`, `grpcPort: 50051`, `grpcSecure: false`. In `initProd()`, set the production host (e.g. `'grpc.mind-awake.life'`), `grpcPort: 443`, `grpcSecure: true`. Follow the existing pattern — every field is `final`, declared at the top, required in `Environment._({...})`, and assigned in both static factories. Apply the same changes to `Environment.example.dart` with placeholder values.

- [x] **Task 2: Create `lib/Core/Grpc/GrpcClient.dart`**
  Files: `lib/Core/Grpc/GrpcClient.dart`
  Create a new class `GrpcClient` in `lib/Core/Grpc/`. It must:
  - Accept `String host`, `int port`, and `bool isSecure` via constructor, plus an optional `Stream<void> detachStream` for app-termination shutdown.
  - Create a `ClientChannel` (from `package:grpc/grpc.dart`) using the provided host/port. Toggle credentials based on `isSecure`: `ChannelCredentials.secure()` when true, `ChannelCredentials.insecure()` when false.
  - Expose a lazy getter for each of the 8 generated service clients: `AuthServiceClient`, `BreathSessionServiceClient`, `DeviceServiceClient`, `LiveServiceClient`, `StatsServiceClient`, `SyncServiceClient`, `TelemetryServiceClient`, `UserServiceClient`. Each getter creates the stub on first access using the shared channel (pattern: `late final authService = AuthServiceClient(_channel);`).
  - Expose a `Future<void> shutdown()` method that calls `await _channel.shutdown()`.
  - If `detachStream` is provided, subscribe internally and call `shutdown()` on the first event. Store the subscription in a `StreamSubscription?` field. This follows the constructor-injection rule — `GrpcClient` manages its own subscription.
  - Import stubs from `lib/Core/Grpc/generated/*.pbgrpc.dart`.

  **Note on app-termination shutdown**: `AppLifecycleState.detached` is unreliable on mobile — iOS often kills apps without triggering it, and Android doesn't guarantee code execution in this state. The shutdown is best-effort. This is acceptable because the OS reclaims all resources when the process dies.

### Phase 2: Wiring

- [x] **Task 3: Add `onDetach` stream to AppLifecycleService**
  Files: `lib/Core/AppLifecycleService.dart`
  Add a `_detachController` broadcast `StreamController<void>` (same pattern as existing `_resumeController`). Add an `onDetach` getter that exposes the stream. Add an `_onDetach()` callback with a log line. Update the `AppLifecycleListener` constructor to include `onDetach: _onDetach` alongside the existing `onResume: _onResume`. Close `_detachController` in `dispose()`.

- [x] **Task 4: Register GrpcClient in App.dart**
  Files: `lib/Core/App.dart`
  - Add `GrpcClient` as a field on `App` (same pattern as `httpClient`).
  - In `initialize()`, construct `GrpcClient` using `Environment.instance.grpcHost`, `Environment.instance.grpcPort`, `Environment.instance.grpcSecure`, and `appLifecycleService.onDetach` as the detach stream. Place it right after the `appLifecycleService` construction line (line ~161), before `socketConnectionCoordinator`. Single-line style per the file's style rule.
  - Pass it into the `App._({...})` constructor call.

## Commit Plan
- **Commit 1** (after tasks 1-2): "Add GrpcClient with lazy-initialized service stubs and TLS toggle"
- **Commit 2** (after tasks 3-4): "Wire GrpcClient into App with best-effort shutdown on app detach"
