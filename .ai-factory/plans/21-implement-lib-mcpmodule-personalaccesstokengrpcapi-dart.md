# Plan: Implement PersonalAccessTokenGrpcApi

## Context

Replace the last REST-based API (`PersonalAccessTokenApi` using Dio) with a gRPC implementation that calls `AuthServiceClient` PAT methods (`createToken`, `listTokens`, `deleteToken`). Wire the new implementation in `App.dart` so the entire PAT flow uses gRPC instead of HTTP.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: gRPC API implementation

- [x] **Task 1: Create `PersonalAccessTokenGrpcApi`**
  Files: `lib/McpModule/PersonalAccessTokenGrpcApi.dart`
  Create a new class `PersonalAccessTokenGrpcApi implements IPersonalAccessTokenApi`. It receives `AuthServiceClient` via constructor (same pattern as `BreathSessionGrpcApi` receiving `BreathSessionServiceClient`).

  Implement each method by calling the corresponding gRPC stub and mapping proto responses back to the existing app-level DTOs (`TokenDTO`, `CreateTokenResponse` from `lib/Core/Api/Models/TokenDTO.dart`):

  - **`fetchTokens()`** — call `_authService.listTokens(proto.ListTokensRequest())`, map each `proto.TokenDto` to `TokenDTO(id: dto.id, name: dto.name, createdAt: dto.createdAt)`.
  - **`createToken(CreateTokenRequest request)`** — call `_authService.createToken(proto.CreateTokenRequest(name: request.name))`, map the `proto.CreateTokenResponse` to `CreateTokenResponse(token: response.token, metadata: TokenDTO(id: response.id, name: response.name, createdAt: response.createdAt))`.
  - **`revokeToken(String tokenId)`** — call `_authService.deleteToken(proto.DeleteTokenRequest(id: tokenId))`, return void (discard the response).

  Import proto types with a prefix (`import '...auth.pb.dart' as proto;` and `import '...auth.pbgrpc.dart' show AuthServiceClient;`) following the convention in `BreathSessionGrpcApi`.

- [x] **Task 2: Wire `PersonalAccessTokenGrpcApi` in `App.dart`** (depends on Task 1)
  Files: `lib/Core/App.dart`
  Replace `PersonalAccessTokenApi(httpClient)` on line 130 with `PersonalAccessTokenGrpcApi(grpcClient.authService)`. Update the import at the top of the file: swap `import 'package:mind/Core/Api/PersonalAccessTokenApi.dart'` for `import 'package:mind/McpModule/PersonalAccessTokenGrpcApi.dart'`. The `IPersonalAccessTokenApi` import stays unchanged since the interface is the same. No other wiring changes are needed — `tokenNotifier` already receives the api via the `IPersonalAccessTokenApi` interface, so the swap is transparent.
