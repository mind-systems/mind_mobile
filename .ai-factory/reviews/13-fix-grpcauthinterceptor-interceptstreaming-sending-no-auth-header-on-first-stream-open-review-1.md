# Code Review: Fix `GrpcAuthInterceptor.interceptStreaming` sending no auth header on first stream open

**Plan:** `13-fix-grpcauthinterceptor-interceptstreaming-sending-no-auth-header-on-first-stream-open.md`
**Files changed:** `lib/Core/Grpc/GrpcAuthInterceptor.dart`

## Scope of review

`git status` / `git diff HEAD` show three staged paths:
- `.ai-factory/plan-reviews/...-plan-review-1.md` — documentation, not code.
- `.ai-factory/plans/...md` — plan file, not code.
- `lib/Core/Grpc/GrpcAuthInterceptor.dart` — the only code change.

I read `GrpcAuthInterceptor.dart` in full (62 lines) post-edit.

## Verification of the fix

1. `_cachedToken` field declaration removed (was line 13).
2. `_cachedToken = token;` side-effect inside `_addAuthMetadata` removed; the method now only reads from `_storage` and writes the `authorization` entry if present (lines 19-24).
3. `interceptStreaming` now merges `CallOptions(providers: [_addAuthMetadata])` (line 54) — byte-for-byte identical to `interceptUnary` line 39. Symmetry achieved.
4. UNAUTHENTICATED detection on `response.trailers` (lines 56-58) is preserved.

Grep across the repo confirmed `_cachedToken` had no other readers (only references in the now-edited file and the roadmap entry). Removal is safe.

## Runtime correctness

- `CallOptions.providers` accepts `Future<void> Function(Map<String, String>, String)`; `_addAuthMetadata` matches. The gRPC Dart client awaits all providers before sending the HTTP/2 HEADERS frame, so the async `_storage.read` resolves before the stream opens. Streams launched immediately after `GrpcConnectionManager.connect()` (e.g. `SyncGrpcListener`, `ModuleStateChannel`) will now carry a fresh `Bearer` header on the first attempt, breaking the UNAUTHENTICATED reconnect loop.
- No race: each stream call goes through its own provider invocation; the token is read at stream-open time, not cached. If the user logs out and the secure storage entry is cleared, subsequent stream re-opens will correctly send no header → server returns UNAUTHENTICATED → existing `_onUnauthenticatedError` triggers `LogoutNotifier`. Logout semantics are preserved.
- Token rotation: previously, a stale `_cachedToken` could outlive a token refresh in storage. After the change, every stream open re-reads storage, eliminating this latent staleness bug as a side benefit.

## Security

- No secrets logged. `_addAuthMetadata` does not log the token.
- No widening of auth surface — the same `authorization` header semantics apply to both unary and streaming now.
- No new external dependencies, no new public API.

## Possible regressions considered

- `interceptUnary` is unchanged (line 39 untouched) — existing unary behavior is preserved.
- `_onUnauthenticatedError` path unchanged — UNAUTHENTICATED still triggers logout.
- The interceptor has no constructor body that referenced `_cachedToken`; removing the field cannot leave a dangling init.
- No callers of the interceptor depended on `_cachedToken` being populated as a side-effect (grep-confirmed).
- `mergedWith` on `CallOptions` correctly composes metadata providers; if a caller passed their own providers, both run. No change in this regard versus unary.

## Findings

None.

REVIEW_PASS
