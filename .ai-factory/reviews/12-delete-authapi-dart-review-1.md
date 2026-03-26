# Review: Delete AuthApi.dart

## Scope

4 file deletions, 2 doc updates. Reviewed against plan 12 and the actual `AuthGrpcApi.dart` implementation.

## File Deletions — PASS

- `lib/Core/Api/AuthApi.dart` — no remaining imports in any `.dart` file. `App.dart` instantiates `AuthGrpcApi`, not `AuthApi`. Safe to delete.
- `lib/Core/Api/Models/SendCodeRequest.dart`, `VerifyCodeRequest.dart`, `GoogleAuthRequest.dart` — only imported by `AuthApi.dart`. The identically-named protobuf types in `lib/Core/Grpc/generated/auth.pb.dart` are separate classes accessed via `proto.` prefix. Safe to delete.

## ARCHITECTURE.md Update — PASS

Line 240: replaced deleted DTO names (`SendCodeRequest`, `VerifyCodeRequest`, `GoogleAuthRequest`) with surviving ones (`SaveBreathSessionRequest`, `StarSessionRequest`, `DevicePingRequest`). All three replacement files exist in `lib/Core/Api/Models/`. Correct.

## jwt-authentication.md Update — FAIL

Line 13 was rewritten to describe gRPC-based token extraction, but the new text contains three factual errors when compared to `AuthGrpcApi.dart`:

### Critical Issue 1: Token source is wrong

**Doc says:** "Сервер возвращает JWT в метаданных ответа под ключом `authorization` с префиксом Bearer"

**Actual code** (`AuthGrpcApi.dart:23,30`): The token comes from `response.accessToken` — a field in the protobuf `AuthResponse` message body. There is no metadata extraction. The token arrives as a plain proto field, not in gRPC response metadata headers.

### Critical Issue 2: No prefix removal happens

**Doc says:** "AuthGrpcApi считывает метаданные, удаляет префикс"

**Actual code:** `_storage.write(key: _tokenKey, value: response.accessToken)` — the value is stored directly. There is no `replaceFirst('Bearer ', '')` or any prefix stripping. The old `AuthApi` had prefix removal because HTTP headers used the `Bearer ` prefix; the proto field contains the raw token.

### Critical Issue 3: Token is not saved via HttpClient

**Doc says:** "делегирует сохранение в HttpClient, который записывает токен в защищённое хранилище (FlutterSecureStorage)"

**Actual code:** `AuthGrpcApi` writes directly to `FlutterSecureStorage` via `_storage.write(...)`. It has no `HttpClient` dependency at all. The constructor is `AuthGrpcApi(this._authService, this._storage)` where `_storage` is `FlutterSecureStorage`.

### Suggested fix for line 13

Replace the first two sentences with something like:

> Токен извлекается из тела gRPC-ответа при первичной аутентификации. Сервер возвращает объект пользователя и JWT-токен как поле `accessToken` в protobuf-сообщении `AuthResponse`. AuthGrpcApi считывает это поле и записывает токен напрямую в защищённое хранилище (FlutterSecureStorage).

The rest of the paragraph (two cleanup scenarios: explicit logout vs 401/unauthenticated) is still accurate at the UserNotifier level and can stay.

## Observations (out of scope, not blocking)

- `lib/Core/Api/AuthInterceptor.dart` still exists on disk despite commit c908c4b ("Remove `lib/Core/Api/AuthInterceptor.dart`"). It is not referenced by this plan, but its continued existence means `jwt-authentication.md` paragraphs 1–4 (which describe the Dio-based `AuthInterceptor` flow) are not yet stale. Once that file is actually deleted, the entire doc will need a rewrite beyond just line 13.

## Verdict

The file deletions and ARCHITECTURE.md update are correct. The jwt-authentication.md update introduces factual inaccuracies about how `AuthGrpcApi` extracts and stores the token. Fix the three issues above before committing.

REVIEW_FAIL
