# Review: Create lib/Core/Grpc/GrpcAuthInterceptor.dart

**Files reviewed:** `lib/Core/Grpc/GrpcAuthInterceptor.dart` (new, 68 lines)
**Cross-referenced:** `lib/Core/Api/AuthInterceptor.dart`, `lib/User/LogoutNotifier.dart`, `lib/Core/Grpc/GrpcClient.dart`, grpc 5.1.0 package source
**Risk level:** Low

## API Correctness

All method signatures verified against grpc 5.1.0 source (`~/.pub-cache/hosted/pub.dev/grpc-5.1.0/`):

- `ClientInterceptor.interceptUnary<Q, R>` — parameter types and return type match exactly
- `ClientInterceptor.interceptStreaming<Q, R>` — parameter types and return type match exactly
- `CallOptions` constructor — accepts both `providers: List<MetadataProvider>` and `metadata: Map<String, String>` named parameters
- `CallOptions.mergedWith(CallOptions?)` — exists, returns new `CallOptions`
- `MetadataProvider` typedef — `FutureOr<void> Function(Map<String, String> metadata, String uri)` matches `_addAuthMetadata` signature
- `ResponseFuture<R>.trailers` / `ResponseStream<R>.trailers` — both return `Future<Map<String, String>>`
- `StatusCode.unauthenticated` — exists, value `16`
- `GrpcError.code` — `int` property, comparable to `StatusCode` constants

## Error Handling

The `.then<void>((_) {}, onError: ...)` pattern is correct:
- Produces `Future<void>`, so the `onError` handler returning void is type-safe
- The original `ResponseFuture<R>` / `ResponseStream<R>` is returned unmodified — caller receives the full `GrpcError`
- `unawaited` suppresses the lint; the derived `Future<void>` completes cleanly whether the call succeeds or fails

## Constructor and DI

Constructor shape matches `AuthInterceptor` exactly — same parameter names, same private field pattern. `_tokenKey` uses the same `'jwt_token'` constant shared across `AuthInterceptor`, `HttpClient`, and `LiveSocketService`.

## `_cachedToken` Design

- Set by `_addAuthMetadata` on every unary call (including to `null` when token absent — correct, clears stale cache)
- Read synchronously by `interceptStreaming` — design assumes at least one prior unary call, documented in plan
- Collection-if guard `if (_cachedToken != null)` prevents `'Bearer null'` — string interpolation of `String?` is safe here since the guard and interpolation execute in the same synchronous expression

## No Issues Found

The implementation is clean, type-safe, and consistent with the existing `AuthInterceptor` pattern. All gRPC package APIs are used correctly.

REVIEW_PASS
