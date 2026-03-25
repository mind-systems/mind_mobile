# Plan: Instantiate GrpcAuthInterceptor once in App._init()

## Context

Wire `GrpcAuthInterceptor` into the app initialization chain so that every gRPC stub automatically attaches JWT tokens and handles unauthenticated errors. Currently `GrpcClient` creates stubs without interceptors, and `GrpcAuthInterceptor` exists but is never instantiated.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Wire interceptor through GrpcClient

- [x] **Task 1: Accept interceptors in GrpcClient constructor and forward to every stub**
  Files: `lib/Core/Grpc/GrpcClient.dart`
  Add a `List<ClientInterceptor> interceptors` parameter (default `const []`) to `GrpcClient`'s constructor. Store it as a private field `final List<ClientInterceptor> _interceptors` — following the existing `_channel` pattern — via initializer list (`_interceptors = interceptors`). Then pass `interceptors: _interceptors` to every `late final` stub initializer (`AuthServiceClient`, `BreathSessionServiceClient`, `DeviceServiceClient`, `LiveServiceClient`, `StatsServiceClient`, `SyncServiceClient`, `TelemetryServiceClient`, `UserServiceClient`). The field is required because `late final` initializers can only reference instance members, not constructor parameters. Follow the existing single-line style.

- [x] **Task 2: Create GrpcAuthInterceptor in App.initialize() and pass to GrpcClient**
  Files: `lib/Core/App.dart`
  In `App.initialize()`, right before the `grpcClient` line (line 165), create:
  `final grpcAuthInterceptor = GrpcAuthInterceptor(storage: const FlutterSecureStorage(), logoutNotifier: logoutNotifier);`
  Then update the `GrpcClient(...)` call to include `interceptors: [grpcAuthInterceptor]`. Both `FlutterSecureStorage` and `logoutNotifier` are already available at that point in the initialization chain. Keep single-line style per the App.dart style rule. Add `import 'package:mind/Core/Grpc/GrpcAuthInterceptor.dart';` to imports.
