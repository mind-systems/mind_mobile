# Code Review: Instantiate GrpcAuthInterceptor once in App._init()

## Files Reviewed
- `lib/Core/Grpc/GrpcClient.dart` (full file, 43 lines)
- `lib/Core/App.dart` (full file, 248 lines)
- `lib/Core/Grpc/GrpcAuthInterceptor.dart` (full file, 68 lines — unchanged, read for context)
- `lib/Core/Grpc/generated/*.pbgrpc.dart` (constructor signatures verified)

## Verified

1. **`_interceptors` field pattern** — stored as `final List<ClientInterceptor> _interceptors`, assigned in initializer list, referenced by `late final` stub initializers. Follows the existing `_channel` pattern. Compiles correctly.

2. **Generated stub compatibility** — all 8 stubs (`AuthServiceClient`, `BreathSessionServiceClient`, etc.) extend `$grpc.Client` with constructor `(super.channel, {super.options, super.interceptors})`. The `interceptors:` named parameter is accepted.

3. **Dependency ordering in App.initialize()** — `logoutNotifier` created at line 121, `const FlutterSecureStorage()` needs no prior init, `grpcAuthInterceptor` created at line 166, `grpcClient` at line 167. All dependencies available.

4. **FlutterSecureStorage reuse** — `const FlutterSecureStorage()` is used in three places (HTTP `AuthInterceptor`, `LiveSocketService`, `GrpcAuthInterceptor`). Since `FlutterSecureStorage` has a `const` constructor, all instances are the identical compile-time constant. No duplication or inconsistency.

5. **Import** — `GrpcAuthInterceptor` import added at line 47, alphabetically between `AppLifecycleService` and `GrpcClient`. Correct.

6. **Style** — single-line initializer style maintained per App.dart style rule. No trailing commas.

7. **Default parameter** — `interceptors = const []` means `GrpcClient` remains usable without interceptors (e.g., in tests). Non-breaking change.

## Critical Issues

None.

## Suggestions

None.

REVIEW_PASS
