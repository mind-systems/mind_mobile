# Plan: Create lib/Core/Grpc/GrpcAuthInterceptor.dart

## Context
Creates the gRPC client interceptor that attaches JWT tokens to outgoing calls and triggers logout on unauthenticated (code 16) errors — the gRPC equivalent of the existing Dio `AuthInterceptor`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Interceptor Implementation

- [x] **Task 1: Create `GrpcAuthInterceptor` class with `interceptUnary`**
  Files: `lib/Core/Grpc/GrpcAuthInterceptor.dart`

  Create a new file with a class extending `ClientInterceptor` (from `package:grpc/grpc.dart`).

  **Constructor** — mirror the existing `AuthInterceptor` pattern (`lib/Core/Api/AuthInterceptor.dart`):
  - Required named parameters: `FlutterSecureStorage storage`, `LogoutNotifier logoutNotifier`
  - Store as private `_storage` and `_logoutNotifier` fields
  - Private constant `static const String _tokenKey = 'jwt_token'` (same key used by `AuthInterceptor`, `HttpClient`, `LiveSocketService`)
  - Private mutable field `String? _cachedToken` — holds the last-known token for synchronous access by `interceptStreaming`

  **Private helper `_addAuthMetadata`** — matches the `MetadataProvider` typedef (`FutureOr<void> Function(Map<String, String> metadata, String uri)`):
  - Async reads token via `_storage.read(key: _tokenKey)`
  - Writes `_cachedToken = token` (cache for streaming use)
  - If non-null, sets `metadata['authorization'] = 'Bearer $token'` (lowercase key — gRPC metadata keys must be lowercase)
  - **No endpoint filtering needed** — unlike the Dio `AuthInterceptor` which skips `/auth/authenticate`, gRPC services have no auth-specific endpoints; all gRPC calls are to authenticated domain services, and the REST auth flow remains on Dio

  **Private helper `_onUnauthenticatedError`** — accepts `Object error`, checks `error is GrpcError && error.code == StatusCode.unauthenticated`, calls `_logoutNotifier.triggerLogout()` when matched. Extracted as a shared method since both `interceptUnary` and `interceptStreaming` use identical logic.

  **`interceptUnary` override:**
  - Merge incoming `options` with `CallOptions(providers: [_addAuthMetadata])` via `options.mergedWith(...)` — the `MetadataProvider` handles the async token read internally within the gRPC client machinery
  - Call `invoker(method, request, mergedOptions)` to obtain the `ResponseFuture<R>`
  - Attach a side-effect error listener: `unawaited(response.then<void>((_) {}, onError: (Object e) { _onUnauthenticatedError(e); }))` — `.then<void>` produces a `Future<void>`, so the `onError` handler returning void is type-safe; do **not** use `.catchError` because `ResponseFuture<R>.catchError` returns `Future<R>` and the void handler would produce a null-completion `TypeError` on the derived future. The original `ResponseFuture<R>` still propagates the `GrpcError` to the caller
  - Return the original `ResponseFuture<R>`

- [x] **Task 2: Add `interceptStreaming` override**
  Files: `lib/Core/Grpc/GrpcAuthInterceptor.dart`

  **`interceptStreaming` override** — this method is sync (returns `ResponseStream<R>` directly, not a `Future`):
  - Build merged options using cached token: `options.mergedWith(CallOptions(metadata: { if (_cachedToken != null) 'authorization': 'Bearer $_cachedToken' }))` — uses static metadata from `_cachedToken` instead of an async `MetadataProvider`, since the token was already cached by a prior `interceptUnary` call (the roadmap states streaming calls are only opened after at least one successful unary call)
  - Call `invoker(method, requests, mergedOptions)` to obtain the `ResponseStream<R>`
  - Pipe errors via the `response.trailers` future: `unawaited(response.trailers.then<void>((_) {}, onError: (Object e) { _onUnauthenticatedError(e); }))` — `.then<void>` produces a `Future<void>`, so the `onError` handler returning void is type-safe; do **not** use `.catchError` because `Future<Map<String, String>>.catchError` returns `Future<Map<String, String>>` and the void handler would produce a null-completion `TypeError`. The `trailers` future errors when the RPC fails, acting as a side-channel error observer without consuming the single-subscription main stream
  - Return the original `ResponseStream<R>`
