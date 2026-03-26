# Review: Implement PersonalAccessTokenGrpcApi

## Files reviewed

- `lib/McpModule/PersonalAccessTokenGrpcApi.dart` (new)
- `lib/Core/App.dart` (modified, lines 22 and 130)

## Cross-referenced

- `lib/Core/Api/IPersonalAccessTokenApi.dart` — interface contract
- `lib/Core/Api/Models/TokenDTO.dart` — `TokenDTO` and `CreateTokenResponse` DTOs
- `lib/Core/Api/Models/CreateTokenRequest.dart` — app-level request DTO
- `lib/Core/Grpc/generated/auth.pb.dart` — proto `TokenDto`, `CreateTokenRequest`, `CreateTokenResponse`, `ListTokensRequest`, `DeleteTokenRequest`
- `lib/Core/Grpc/generated/auth.pbgrpc.dart` — `AuthServiceClient` stub methods
- `lib/McpModule/Core/TokenNotifier.dart` — consumer of `IPersonalAccessTokenApi`
- `lib/BreathModule/Core/BreathSessionGrpcApi.dart` — reference implementation for pattern

## Findings

### Correctness

**All three method implementations are correct:**

1. `fetchTokens()` — maps `proto.TokenDto` fields (`id`, `name`, `createdAt`) to `TokenDTO`. The proto `lastUsedAt` field is intentionally dropped since `TokenDTO` doesn't carry it. Verified that `TokenNotifier.loadTokens()` calls `DateTime.parse(dto.createdAt)` on the result, which will work with the ISO 8601 string the server sends via proto.

2. `createToken()` — maps app `CreateTokenRequest.name` to `proto.CreateTokenRequest(name:)`, then maps the proto response into `CreateTokenResponse(token:, metadata: TokenDTO(...))`. Field mapping matches what `TokenNotifier.createToken()` reads: `response.metadata.id`, `response.metadata.name`, `response.metadata.createdAt`.

3. `revokeToken()` — passes `tokenId` to `proto.DeleteTokenRequest(id:)`, discards the `DeleteTokenResponse`. Matches the old REST `delete('/auth/tokens/$tokenId')` semantics.

### Name collision avoidance

Both the proto stubs and the app-level models define `CreateTokenRequest` / `CreateTokenResponse`. The proto import uses a prefix (`as proto`), so `proto.CreateTokenRequest` vs the unprefixed app-level `CreateTokenRequest` — no ambiguity. Follows the same convention as `BreathSessionGrpcApi`.

### Stub sharing

`grpcClient.authService` is shared with `AuthGrpcApi` (line 128 in App.dart). This is fine — gRPC stubs are stateless wrappers over the channel. Each call creates an independent RPC.

### Error handling

`TokenNotifier` uses generic `catch (e)` for all three operations, logging `e.toString()` and emitting `TokenError`. The switch from `DioException` to `GrpcError` is transparent — both are caught and serialized the same way. The `GrpcAuthInterceptor` already handles `StatusCode.unauthenticated` (gRPC 401 equivalent) by triggering logout, matching the old `AuthInterceptor` behavior for REST.

### App.dart wiring

Import swap is correct: `PersonalAccessTokenApi` → `PersonalAccessTokenGrpcApi`. The `IPersonalAccessTokenApi` import is retained. Line 130 now passes `grpcClient.authService` instead of `httpClient`. The typed field `IPersonalAccessTokenApi tokenApi` on the `App` class ensures the substitution is type-safe.

## Issues

None found.

REVIEW_PASS
