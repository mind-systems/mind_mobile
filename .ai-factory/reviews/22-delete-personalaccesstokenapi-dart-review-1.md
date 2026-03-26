# Review: Delete PersonalAccessTokenApi.dart

## Files reviewed

- `lib/Core/Api/PersonalAccessTokenApi.dart` — deleted
- `lib/Core/Api/Models/TokenDTO.dart` — `TokenDTO.fromJson` and `CreateTokenResponse.fromJson` removed
- `lib/Core/Api/Models/CreateTokenRequest.dart` — `toJson()` removed
- `.ai-factory/ROADMAP.md` — milestone 2.10 marked complete
- `.ai-factory/plans/22-delete-personalaccesstokenapi-dart.md` — new plan file

## Callers verified

- `lib/Core/App.dart` — imports `PersonalAccessTokenGrpcApi` (line 22) and `IPersonalAccessTokenApi` (line 23). Does not import the deleted class. Wires `PersonalAccessTokenGrpcApi(grpcClient.authService)` at line 130. No change needed.
- `lib/McpModule/PersonalAccessTokenGrpcApi.dart` — constructs `TokenDTO(id:, name:, createdAt:)` and `CreateTokenResponse(token:, metadata:)` directly from proto fields. Never calls `fromJson` or `toJson`. No change needed.
- `lib/McpModule/Core/TokenNotifier.dart` — calls `CreateTokenRequest(name: name)` constructor and reads `response.metadata.id`, `.name`, `.createdAt` fields. Never calls any removed method. No change needed.
- `lib/Core/Api/IPersonalAccessTokenApi.dart` — interface references `CreateTokenRequest` and `TokenDTO`/`CreateTokenResponse` by type only. No dependency on removed methods. No change needed.

## Findings

No issues found. The deleted file had zero importers. The removed `fromJson`/`toJson` methods had no callers outside the deleted file. The interface and remaining DTO classes retain all fields and constructors used by `PersonalAccessTokenGrpcApi` and `TokenNotifier`. Roadmap checkbox is correct.

REVIEW_PASS
