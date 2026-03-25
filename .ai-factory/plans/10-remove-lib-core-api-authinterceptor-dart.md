# Plan: Remove lib/Core/Api/AuthInterceptor.dart

## Context

Deletes the Dio-based `AuthInterceptor` after all HTTP APIs have been migrated to gRPC stubs. `GrpcAuthInterceptor` handles JWT attachment and unauthenticated-error logout for all gRPC calls, making the Dio interceptor dead code.

## Prerequisites

> **🚫 BLOCKED — do not execute until all prerequisites are met.**
>
> This plan depends on milestones **2.5–2.11** (ROADMAP.md Phase 2) being fully complete — every Dio-based API must be replaced by its gRPC equivalent and the old `*Api.dart` files deleted. The ROADMAP explicitly gates this removal (Phase 2.4 line: "only after all Dio-based APIs are replaced") and repeats the guard in Phase 4.3.
>
> **Before executing, verify:**
> 1. `grep -r "import.*HttpClient" lib/` returns zero hits outside `App.dart` and `HttpClient.dart` itself
> 2. All six Dio API files are deleted: `AuthApi.dart`, `UserApi.dart`, `BreathSessionApi.dart`, `SyncApi.dart`, `DeviceApi.dart`, `PersonalAccessTokenApi.dart`
> 3. All ROADMAP milestones 2.5–2.11 are checked (`[x]`)

## Settings
- Testing: no
- Logging: minimal
- Docs: yes (existing docs reference the deleted file and must be updated)

## Tasks

### Phase 1: Remove AuthInterceptor from code

- [ ] **Task 1: Delete `AuthInterceptor.dart` and update `HttpClient.dart`**
  Files: `lib/Core/Api/AuthInterceptor.dart`, `lib/Core/Api/HttpClient.dart`
  Delete `lib/Core/Api/AuthInterceptor.dart`. In `HttpClient.dart`:
  - Remove the `import 'package:mind/Core/Api/AuthInterceptor.dart';` import
  - Remove the `required AuthInterceptor authInterceptor` constructor parameter
  - Remove the `_dio.interceptors.add(authInterceptor);` line inside the constructor body
  - Remove the `FlutterSecureStorage _storage` field and the `_tokenKey` constant — these exist only for `saveToken`/`clearToken`, which are token-management methods that become orphaned once `AuthInterceptor` is gone (token storage is now handled by `GrpcAuthInterceptor` via its own `FlutterSecureStorage` instance)
  - Remove the `saveToken()` and `clearToken()` methods — verify with `grep -r "saveToken\|clearToken" lib/` that no callers remain before deleting; if callers exist, leave these methods in place and note in the commit message
  - Remove the `flutter_secure_storage` import if no longer used in the file
  - `HttpClient` remains functional as a plain Dio wrapper (still used until Phase 4 removes Dio entirely) — it just no longer attaches an interceptor or manages tokens

- [ ] **Task 2: Update `App.dart` initialization** (depends on Task 1)
  Files: `lib/Core/App.dart`
  - Remove the `import 'package:mind/Core/Api/AuthInterceptor.dart';` import
  - Find and remove the line that creates the `AuthInterceptor` instance (`final authInterceptor = AuthInterceptor(...)`)
  - Update the `HttpClient(...)` constructor call to remove the `authInterceptor` parameter — result should be `final httpClient = HttpClient();`
  - Keep single-line style per the App.dart style rule (comment at top of file)
  - Note: by the time this plan executes, `App.dart` will have changed substantially from milestones 2.5–2.11 (new gRPC APIs wired, old Dio APIs removed). Locate the correct lines by content, not by line number.

- [ ] **Task 3: Update `LogoutNotifier.dart` doc comments** (depends on Task 1)
  Files: `lib/User/LogoutNotifier.dart`
  Replace `[AuthInterceptor]` references in the doc comment with `[GrpcAuthInterceptor]`. The comment currently describes `AuthInterceptor` as the producer that calls `triggerLogout` on 401 responses — update both mentions to reference `[GrpcAuthInterceptor]` and `StatusCode.unauthenticated` instead of 401 for accuracy.

### Phase 2: Update documentation and project config

- [ ] **Task 4: Update project configuration files** (depends on Task 1)
  Files: `CLAUDE.md`, `AGENTS.md`, `.ai-factory/DESCRIPTION.md`, `.ai-factory/ARCHITECTURE.md`, `.ai-factory/ROADMAP.md`
  Minimal updates — replace or remove `AuthInterceptor` mentions:
  - `CLAUDE.md`: find the bullet about `AuthInterceptor` in the Authentication flow section and replace with equivalent text about `GrpcAuthInterceptor` handling JWT and unauthenticated errors
  - `AGENTS.md`: find the `AuthInterceptor` entry in the Key Entry Points table and replace with `lib/Core/Grpc/GrpcAuthInterceptor.dart`, update the purpose column
  - `.ai-factory/DESCRIPTION.md`: update the Tech Stack HTTP Client line (currently "Dio 5.x with `AuthInterceptor` for JWT attach + 401 handling") to reflect that Dio is still present but auth is handled by gRPC. Also update the Non-Functional Requirements section (currently says "auth interceptor handles token refresh + logout on 401") to reference `GrpcAuthInterceptor` and `StatusCode.unauthenticated`
  - `.ai-factory/ARCHITECTURE.md`: update the `Api/` folder comment (currently "Dio client + AuthInterceptor") to "Dio client (legacy, no interceptor)". Also update the DI Wiring initialization order diagram — remove "Auth Interceptor" from the chain
  - `.ai-factory/ROADMAP.md`: check off the Phase 2.4 item for removing `AuthInterceptor`. If Phase 4.3 still references deleting `AuthInterceptor.dart`, update it to note the file is already deleted (only `HttpClient.dart` and `flutter pub remove dio` remain for Phase 4.3)

- [ ] **Task 5: Update feature documentation** (depends on Task 1)
  Files: `docs/core/jwt-authentication.md`, `docs/core/global-listeners.md`, `docs/core/testing.md`, `docs/user/login-flow.md`
  These docs are written in Russian — preserve the language when editing.
  - `docs/core/jwt-authentication.md`: replace all `AuthInterceptor` mentions with `GrpcAuthInterceptor`. Update the description of how tokens are attached (gRPC metadata instead of HTTP headers) and how unauthenticated errors are caught (`StatusCode.unauthenticated` instead of HTTP 401). Keep the same narrative structure.
  - `docs/core/global-listeners.md`: replace `AuthInterceptor` with `GrpcAuthInterceptor` in the 401 handling chain description. Update "401" to "unauthenticated" where it refers to the interceptor's trigger.
  - `docs/core/testing.md`: replace `AuthInterceptor` with `GrpcAuthInterceptor` in the infrastructure layer row; update "Dio" to "gRPC" in the mocking note.
  - `docs/user/login-flow.md`: replace `AuthInterceptor` with `GrpcAuthInterceptor` in the cross-reference link text.

## Commit Plan
- **Commit 1** (after tasks 1-3): "Remove AuthInterceptor and update code references to GrpcAuthInterceptor"
- **Commit 2** (after tasks 4-5): "Update documentation and project config after AuthInterceptor removal"
