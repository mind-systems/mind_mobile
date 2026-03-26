# Review: Delete AuthApi.dart (Round 2)

## Scope

4 file deletions, 2 doc updates. Follow-up review after three critical issues from review-1 were addressed.

## Review-1 Issues — All Resolved

1. **Token source** — fixed. Doc now correctly says token comes from `accessToken` field in the protobuf `AuthResponse` body, not from gRPC metadata. Matches `AuthGrpcApi.dart:23,30`.
2. **No prefix removal** — fixed. Doc no longer mentions prefix stripping. Matches code: `_storage.write(key: _tokenKey, value: response.accessToken)`.
3. **Direct storage, not HttpClient** — fixed. Doc now says "записывает токен напрямую в защищённое хранилище (FlutterSecureStorage)". Matches constructor `AuthGrpcApi(this._authService, this._storage)` where `_storage` is `FlutterSecureStorage`.

## File Deletions — PASS

- `lib/Core/Api/AuthApi.dart` — zero imports in any `.dart` file. `App.dart` wires `AuthGrpcApi`.
- `lib/Core/Api/Models/SendCodeRequest.dart`, `VerifyCodeRequest.dart`, `GoogleAuthRequest.dart` — only imported by the deleted `AuthApi.dart`. Protobuf types with identical names in `auth.pb.dart` are accessed via `proto.` prefix in `AuthGrpcApi` and are unaffected.

## ARCHITECTURE.md — PASS

Line 240: anti-pattern examples replaced with `SaveBreathSessionRequest`, `StarSessionRequest`, `DevicePingRequest`. All three exist in `lib/Core/Api/Models/`.

## jwt-authentication.md — PASS

Line 13 now accurately describes the gRPC token flow: token extracted from `AuthResponse.accessToken` proto field, written directly to `FlutterSecureStorage` by `AuthGrpcApi`. The rest of the paragraph (logout vs 401 cleanup scenarios) remains accurate at the `UserNotifier` level.

## Dangling references check — PASS

Grep for deleted file paths found matches only in `.ai-factory/` meta-files (plans, reviews, roadmap) — expected and harmless.

## Observations (not blocking)

- `ROADMAP.md:34` still lists "Delete AuthApi.dart" as an open task. Should be checked off after commit, but that's a post-merge housekeeping step, not a code issue.

REVIEW_PASS
