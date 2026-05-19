# Plan Review: Fix `GrpcAuthInterceptor.interceptStreaming` sending no auth header on first stream open

**Plan:** `13-fix-grpcauthinterceptor-interceptstreaming-sending-no-auth-header-on-first-stream-open.md`
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md:** PASS. The change is confined to `lib/Core/Grpc/GrpcAuthInterceptor.dart`, which is part of the Core/Grpc infrastructure layer. No layer/boundary violation.
- **RULES.md:** PASS. The three project rules (stateless module services, App.dart purity, constructor DI) are unrelated to this fix. In fact, removing `_cachedToken` brings the interceptor closer to a stateless-cache-free design, which aligns with the project's stateless-service ethos.
- **ROADMAP.md:** PASS. Roadmap line 23 describes this exact fix verbatim — plan and roadmap entry match step-for-step (provider-based replacement + removal of `_cachedToken`).

## Diagnosis Verification

Confirmed against `lib/Core/Grpc/GrpcAuthInterceptor.dart`:

- Line 13: `String? _cachedToken;` — present, exactly as plan states.
- Line 21-27: `_addAuthMetadata` reads from `_storage` and assigns `_cachedToken = token` as a side effect (line 23). Correct.
- Line 42 (`interceptUnary`): `options.mergedWith(CallOptions(providers: [_addAuthMetadata]))` — provider-based, the correct reference implementation.
- Lines 57-61 (`interceptStreaming`): builds metadata literal from the cached field — confirmed bug.
- `_cachedToken` is referenced **only** inside this file (grep across repo confirms). Safe to remove.

The root-cause analysis is accurate: streams opened before any unary call (the documented case for `SyncGrpcListener` + `ModuleStateChannel` after `GrpcConnectionManager.connect()`) will indeed serialize a `null` token, omit the `authorization` header, and trigger an `UNAUTHENTICATED` reconnect loop.

## Fix Correctness

`CallOptions(providers: [...])` accepts `Future<void> Function(Map<String, String>, String)` — `_addAuthMetadata` matches this signature exactly. The gRPC Dart client awaits all metadata providers before opening the stream, so the async `_storage.read` will resolve before the HTTP/2 HEADERS frame is sent. Behavior under streaming will become identical to unary, which is the desired property.

## Concerns / Nits

- **None blocking.** After removal, the unawaited side-effect `_cachedToken = token` on line 23 disappears, which is the entire point. Nothing else in the codebase observes `_cachedToken`.
- **Logging:** plan says "minimal" logging. Since the file has no existing log calls and the existing UNAUTHENTICATED detection (`trailers.then`, line 63-65) remains intact, no extra logging is needed. Plan is consistent.
- **Testing:** plan explicitly opts out (`Testing: no`). Acceptable given the change is a 4-line surface-area swap with a clear matching reference (`interceptUnary`), and the project has no existing interceptor tests to extend.
- **Token refresh / rotation:** removing `_cachedToken` actually fixes a latent bug — if the token rotated between login flows, the cached value could have been stale on subsequent streams. After this change, every stream open re-reads from secure storage. Net positive, no regression risk.

## Positive Notes

- Plan is tightly scoped (2 tasks, one file, < 10 LOC delta).
- Reuses the existing, proven provider path rather than inventing a new mechanism — minimum-blast-radius fix.
- Removes dead state instead of papering over the bug.
- Line numbers and signatures in the plan match the live file.

PLAN_REVIEW_PASS
