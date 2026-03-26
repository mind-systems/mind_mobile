# Plan: Delete Dio infrastructure

## Context
All REST API implementations have been replaced by gRPC stubs (milestones 2.5-2.11) and `GrpcAuthInterceptor` is active. The Dio HTTP client, its auth interceptor, and the `dio` package dependency are now dead code and can be fully removed. This also cleans up stale Dio/AuthInterceptor references in project configuration files.

## Settings
- Testing: no
- Logging: minimal
- Docs: no (stale references in `docs/` will be handled in a separate follow-up plan)

## Tasks

### Phase 1: Delete Dio files and clean references

- [x] **Task 1: Delete Dio source files**
  Files: `lib/Core/Api/HttpClient.dart`, `lib/Core/Api/AuthInterceptor.dart`, `lib/Core/Api/Models/ApiExeption.dart`
  Delete all three files. `HttpClient.dart` is the Dio wrapper, `AuthInterceptor.dart` is the Dio `Interceptor` subclass, and `ApiExeption.dart` is only used by `HttpClient`. The remaining files in `lib/Core/Api/` (`ISyncApi.dart`, `IPersonalAccessTokenApi.dart`, `Models/` except `ApiExeption.dart`) are still actively imported by gRPC implementations and must stay.

- [x] **Task 2: Remove Dio wiring from App.dart** (depends on Task 1)
  Files: `lib/Core/App.dart`
  Remove these six things:
  1. Import of `AuthInterceptor.dart` (line 15)
  2. Import of `HttpClient.dart` (line 19)
  3. Field `final HttpClient httpClient;` (line 64)
  4. Constructor parameter `required this.httpClient,` (line 87)
  5. Two initialization lines: `final authInterceptor = AuthInterceptor(...)` and `final httpClient = HttpClient(...)` (lines 122-123)
  6. Assignment `httpClient: httpClient,` in the `App._()` call (line 175)

  Keep all gRPC wiring untouched. Follow the single-line style rule for `App.dart`.

- [x] **Task 3: Remove dead Environment fields** (depends on Task 1)
  Files: `lib/Core/Environment.dart`, `lib/Core/Environment.example.dart`
  Remove `apiBaseUrl` and `wsBaseUrl` fields from both files. `apiBaseUrl` was only consumed by `HttpClient.dart` (now deleted). `wsBaseUrl` was consumed by the old Socket.io client (already deleted in milestone 3.6). Remove the field declarations, constructor parameters, and all values in `initDev()` / `initProd()` (including commented-out variants).

- [x] **Task 4: Fix LogoutNotifier doc comment** (depends on Task 1)
  Files: `lib/User/LogoutNotifier.dart`
  The class doc comment on lines 3 and 5 references `[AuthInterceptor]` which will be a broken cross-reference after Task 1. Replace both `[AuthInterceptor]` mentions with `[GrpcAuthInterceptor]`.

### Phase 2: Remove Dio dependency

- [x] **Task 5: Remove dio package and verify** (depends on Tasks 1-3)
  Files: `pubspec.yaml`
  Run `/usr/local/bin/flutter pub remove dio` to drop the `dio: ^5.9.0` dependency and regenerate the lockfile. After removal, verify no remaining `package:dio` imports exist anywhere in `lib/` with a grep search. The build should compile cleanly with zero Dio references.

### Phase 3: Update project configuration files

- [x] **Task 6: Update CLAUDE.md** (depends on Task 1)
  Files: `CLAUDE.md`
  Update three stale references:
  1. Line 42: Change `Repository (Drift DB + Dio API)` to `Repository (Drift DB + gRPC API)` in the architecture overview
  2. Line 68: Change `HttpClient (Dio), routing, environment config` to `GrpcClient, routing, environment config` in the module structure table for `lib/Core/`
  3. Lines 115-117: Replace the `AuthInterceptor` authentication flow description. Change from `AuthInterceptor (lib/Core/Api/AuthInterceptor.dart) attaches JWT tokens and handles 401 responses` to `GrpcAuthInterceptor (lib/Core/Grpc/GrpcAuthInterceptor.dart) attaches JWT tokens and handles gRPC UNAUTHENTICATED (code 16) responses`. Update the next line accordingly — on code 16 (not 401) it publishes to `LogoutNotifier`.

- [x] **Task 7: Update DESCRIPTION.md** (depends on Task 1)
  Files: `.ai-factory/DESCRIPTION.md`
  Update five stale references:
  1. Line 13: Change `JWT tokens with auto-refresh via Dio interceptor` to `JWT tokens with auto-refresh via gRPC interceptor`
  2. Line 23: Remove the `HTTP Client: Dio 5.x with AuthInterceptor for JWT attach + 401 handling` line entirely (gRPC client is already listed on line 24)
  3. Line 41: Change `Repository (Drift DB + Dio API)` to `Repository (Drift DB + gRPC API)` in the architecture diagram
  4. Line 63: Change `Dio API client` to `GrpcClient` in the module structure table for `lib/Core/`
  5. Line 72: Change `auth interceptor handles token refresh + logout on 401` to `gRPC auth interceptor handles token attach + logout on UNAUTHENTICATED (code 16)`

- [x] **Task 8: Update ARCHITECTURE.md** (depends on Task 1)
  Files: `.ai-factory/ARCHITECTURE.md`
  Update four stale references:
  1. Line 12: Change `Dio (HTTP)` to `gRPC` in the tech stack
  2. Line 29: Change `Repository (Drift DB + Dio API)` to `Repository (Drift DB + gRPC API)` in the layer stack diagram
  3. Line 40: Change `Dio client + AuthInterceptor` to `GrpcClient + GrpcAuthInterceptor` in the folder structure
  4. Line 204: Change `Drift DAO + Dio calls` to `Drift DAO + gRPC calls` in the new-module checklist

- [x] **Task 9: Mark ROADMAP.md phase 4.3 complete** (depends on Tasks 1-5)
  Files: `.ai-factory/ROADMAP.md`
  Mark the two items under Phase 4.3 as done:
  1. Change `- [ ] **Delete Dio infrastructure**` to `- [x] **Delete Dio infrastructure**`
  2. Change `- [ ] **Remove Dio and verify**` to `- [x] **Remove Dio and verify**`

## Commit Plan
- **Commit 1** (after tasks 1-5): "Delete Dio infrastructure and remove dio package dependency"
- **Commit 2** (after tasks 6-9): "Update project configuration files to reflect Dio removal"
