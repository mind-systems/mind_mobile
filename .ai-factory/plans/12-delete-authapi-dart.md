# Plan: Delete AuthApi.dart

## Context

Remove the old Dio-based `AuthApi` implementation and its three orphaned request DTOs now that `AuthGrpcApi` is fully wired as the `IAuthApi` provider in `App.dart`. Update references in architecture docs and JWT documentation.

## Settings
- Testing: no
- Logging: minimal
- Docs: yes — update ARCHITECTURE.md anti-pattern examples and jwt-authentication.md stale AuthApi reference

## Tasks

### Phase 1: Delete dead files

- [x] **Task 1: Delete AuthApi.dart**
  Files: `lib/Core/Api/AuthApi.dart`
  Delete the file. It implements `IAuthApi` over Dio `HttpClient` but is no longer imported by any production code — `App.dart` instantiates `AuthGrpcApi` instead.

- [x] **Task 2: Delete orphaned Dio request DTOs**
  Files: `lib/Core/Api/Models/SendCodeRequest.dart`, `lib/Core/Api/Models/VerifyCodeRequest.dart`, `lib/Core/Api/Models/GoogleAuthRequest.dart`
  Delete all three files. They are only imported by `AuthApi.dart` (verified via grep). The gRPC path uses protobuf-generated request types from `lib/Core/Grpc/generated/auth.pb.dart` instead.

### Phase 2: Update references

- [x] **Task 3: Update ARCHITECTURE.md anti-pattern examples**
  Files: `.ai-factory/ARCHITECTURE.md`
  Line 240 references the deleted DTOs (`SendCodeRequest`, `VerifyCodeRequest`, `GoogleAuthRequest`) as canonical examples of the typed-DTO pattern. Replace them with surviving Dio DTOs: `SaveBreathSessionRequest`, `StarSessionRequest`, `DevicePingRequest`.

- [x] **Task 4: Update jwt-authentication.md**
  Files: `docs/core/jwt-authentication.md`
  Line 13 says "AuthApi считывает заголовок, удаляет префикс и делегирует сохранение в HttpClient" — this describes the old Dio-based token extraction from HTTP `Authorization` headers. Update the paragraph to reflect that `AuthGrpcApi` now reads tokens from gRPC response metadata instead. Keep the doc language in Russian to match the rest of the file.

### Phase 3: Verify

- [x] **Task 5: Run static analysis**
  Run `dart analyze lib/` from the project root to confirm no broken imports or unresolved references remain after the deletions.
