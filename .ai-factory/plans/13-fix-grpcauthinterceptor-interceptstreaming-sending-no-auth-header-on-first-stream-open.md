# Plan: Fix `GrpcAuthInterceptor.interceptStreaming` sending no auth header on first stream open

## Context
`interceptStreaming` reads `_cachedToken` directly from a stale static-style field that is only populated as a side-effect of `interceptUnary`. When `SyncGrpcListener` and `ModuleStateChannel` open their streams immediately after `GrpcConnectionManager.connect()` — before any unary call has fired — no `authorization` header is sent and the server returns `UNAUTHENTICATED`, causing a reconnect loop. The fix is to use the same `CallOptions(providers: [_addAuthMetadata])` path that unary uses, and remove the now-unused `_cachedToken` field.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Apply fix

- [x] **Task 1: Switch `interceptStreaming` to provider-based auth metadata**
  Files: `lib/Core/Grpc/GrpcAuthInterceptor.dart`
  In `interceptStreaming` (lines 50-67), replace the `CallOptions(metadata: { if (_cachedToken != null) 'authorization': 'Bearer $_cachedToken' })` construction with `CallOptions(providers: [_addAuthMetadata])` — identical to how `interceptUnary` merges options on line 42. This ensures the token is read from `FlutterSecureStorage` lazily at stream-open time, so streams opened before any unary call still receive a valid `Bearer` header.

- [x] **Task 2: Remove the now-unused `_cachedToken` field**
  Files: `lib/Core/Grpc/GrpcAuthInterceptor.dart`
  Delete the `String? _cachedToken;` declaration (line 13) and the `_cachedToken = token;` side-effect assignment inside `_addAuthMetadata` (line 23). Grep confirmed `_cachedToken` is referenced only inside this file, so removal is safe. Keep `_addAuthMetadata` otherwise intact — it still reads from `_storage` and writes the `authorization` header into the metadata map.
