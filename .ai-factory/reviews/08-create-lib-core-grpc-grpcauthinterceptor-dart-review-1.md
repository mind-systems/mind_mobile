## Code Review Summary

**Files Reviewed:** 1 (`lib/Core/Grpc/GrpcAuthInterceptor.dart` — 68 lines, new file)
**Cross-referenced:** `lib/User/LogoutNotifier.dart`, `lib/Core/Grpc/GrpcClient.dart`, grpc 5.1.0 package source (`ClientInterceptor`, `CallOptions`, `MetadataProvider`, `ResponseFuture`, `ResponseStream`, `GrpcError`, `StatusCode`)
**Risk Level:** Low

### Context Gates

- **ARCHITECTURE.md** — WARN: `ARCHITECTURE.md` lists `Api/` as the location for `GrpcClient + GrpcAuthInterceptor`, but the file is placed in `lib/Core/Grpc/`. This is consistent with the actual project layout (all gRPC infra lives under `Grpc/`), so the architecture doc is simply stale — not a code issue.
- **RULES.md** — No violations. All dependencies are constructor-injected. No module-specific state added to App.dart. Class is infrastructure, not a module Service, so statelessness rule does not apply.
- **ROADMAP.md** — Milestone correctly checked off. Next milestone ("Instantiate once in `App._init()`") is already marked done, confirming wiring exists downstream.

### API Correctness (verified against grpc 5.1.0 source)

| API | Verified |
|-----|----------|
| `ClientInterceptor.interceptUnary<Q, R>` signature | Parameter types and return type match exactly |
| `ClientInterceptor.interceptStreaming<Q, R>` signature | Parameter types and return type match exactly |
| `CallOptions(providers: [...])` | Constructor accepts `List<MetadataProvider>?` named param |
| `CallOptions(metadata: {...})` | Constructor accepts `Map<String, String>?` named param |
| `CallOptions.mergedWith(CallOptions?)` | Returns new `CallOptions` — used correctly |
| `MetadataProvider` typedef | `FutureOr<void> Function(Map<String, String>, String)` — `_addAuthMetadata` returns `Future<void>` (subtype) |
| `ResponseFuture<R>.trailers` | `Future<Map<String, String>>` — exists via `Response` interface |
| `ResponseStream<R>.trailers` | `Future<Map<String, String>>` — exists via `Response` interface |
| `GrpcError.code` | `int` property — comparable to `StatusCode` constants |
| `StatusCode.unauthenticated` | `static const int` = 16 |

### Error Handling Pattern

The `.then<void>((_) {}, onError: (Object e) { ... })` pattern is correct and well-chosen:

- Produces `Future<void>` — the `onError` callback returning void is type-safe
- The derived future completes cleanly in all cases (success or error), so `unawaited` never produces an uncaught async error
- The original `ResponseFuture<R>` / `ResponseStream<R>` is returned unmodified — the caller still receives the full `GrpcError`
- Using `.catchError` would be wrong: `ResponseFuture<R>.catchError` returns `Future<R>`, and the void handler would cause a null-completion `TypeError` on the derived future

For streaming, `response.trailers` is a correct side-channel error observer — it errors when the RPC fails without consuming the single-subscription response stream.

### Token Cache Design

- `_cachedToken` is set on every `_addAuthMetadata` call (including to `null` when absent — correctly clears stale cache)
- Read synchronously by `interceptStreaming` — safe in Dart's single-threaded event loop
- Collection-if guard `if (_cachedToken != null)` prevents adding `'Bearer null'` to metadata
- Design assumption (streaming only after unary) is documented in plan and roadmap

### Constructor and DI

- Required named parameters match the existing `AuthInterceptor` pattern
- `_tokenKey = 'jwt_token'` is the same constant used across `AuthInterceptor`, `HttpClient`, and `LiveSocketService`
- Both dependencies are private final fields — immutable after construction

### Positive Notes

- Clean, minimal implementation — 68 lines with no unnecessary abstractions
- Error handling comments in the plan explain the `.then<void>` vs `.catchError` tradeoff — good documentation of a non-obvious Dart gotcha
- Shared `_onUnauthenticatedError` helper avoids duplication between unary and streaming paths
- Lowercase `'authorization'` key follows gRPC metadata convention

REVIEW_PASS
