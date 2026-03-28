# Plan: Restore `lib/Core/Api/HttpClient.dart`

## Context

Re-add the Dio-based HTTP client infrastructure that was removed in commit `bb04376` ("Delete Dio infrastructure"). This restores a REST transport layer (`HttpClient` wrapping Dio with structured error handling via `ApiException`) alongside the existing gRPC layer, so future features can call REST endpoints.

**App.dart wiring is intentionally deferred** — there is no REST consumer yet. When the first feature that needs REST is implemented, that plan will add `HttpClient` to `App._()` fields, constructor params, and `initialize()`. Until then, the class exists as ready-to-wire infrastructure.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Dependency and model

- [x] **Task 1: Add Dio dependency**
  Files: `pubspec.yaml`, `pubspec.lock`
  Run `/usr/local/bin/flutter pub add dio`. This adds `dio` to `dependencies` in `pubspec.yaml` and regenerates `pubspec.lock`.

- [x] **Task 2: Restore `ApiException` model**
  Files: `lib/Core/Api/Models/ApiExeption.dart`
  Create the file with the original content (keep the legacy filename typo `ApiExeption.dart`). The class `ApiException` implements `Exception` with three fields: `message` (`String`, required), `statusCode` (`int?`), `data` (`dynamic`). Include a `toString()` override that formats as `ApiException: [statusCode]: message` when statusCode is present, or `ApiException: message` otherwise. Restore the exact class from git (`git show bb04376^:lib/Core/Api/Models/ApiExeption.dart`).

### Phase 2: Environment and HTTP client

- [x] **Task 3: Add `apiBaseUrl` to Environment** (depends on Task 1)
  Files: `lib/Core/Environment.example.dart`, `lib/Core/Environment.dart`
  Add a `final String apiBaseUrl` field to the `Environment` class. Add the named parameter to the private constructor. Set values in both `initDev()` and `initProd()`:
  - `Environment.example.dart`: use placeholder values — dev: `'http://localhost:3000'` (NestJS default port), prod: `'https://YOUR_PROD_API_URL'`.
  - `Environment.dart`: use real values. Dev should point to `http://localhost:3000` (same host as the NestJS backend). Prod should match the production API domain (same host as gRPC but with the HTTP scheme/port for REST).

- [x] **Task 4: Restore `HttpClient`** (depends on Tasks 1, 2, 3)
  Files: `lib/Core/Api/HttpClient.dart`
  Re-create the Dio wrapper from the original code (`git show bb04376^:lib/Core/Api/HttpClient.dart`) with two adaptations:

  **Adaptation 1 — Interceptor injection:** The original constructor took `AuthInterceptor authInterceptor` — a Dio-specific auth interceptor that was also deleted in `bb04376` and is not part of this milestone. Replace that parameter with `List<Interceptor> interceptors` (from `package:dio/dio.dart`) and wire them via `_dio.interceptors.addAll(interceptors)`. Remove the `AuthInterceptor` import.

  **Adaptation 2 — Constructor-inject `FlutterSecureStorage`:** Per RULES.md ("All dependencies must be injected via constructor"), do NOT instantiate `FlutterSecureStorage` internally. Accept it as a required constructor parameter:
  ```dart
  HttpClient({required List<Interceptor> interceptors, required FlutterSecureStorage storage})
      : _storage = storage {
  ```

  **Adaptation 3 — Remove `saveToken()` / `clearToken()`:** These methods wrote to the `jwt_token` key in `FlutterSecureStorage`, but token management is now owned by `AuthGrpcApi` (writes on login) and `GrpcAuthInterceptor` (reads for gRPC calls). Restoring them would create a dead-code second write path to the same storage key. Drop both methods entirely. If a future REST auth interceptor needs token access, it will read from `FlutterSecureStorage` via its own constructor-injected instance — the same pattern gRPC already uses. Also remove the `_storage` field and the `FlutterSecureStorage` constructor parameter since they were only used by `saveToken`/`clearToken`.

  Keep everything else identical to the original:
  - `Dio` instance configured with `BaseOptions(baseUrl: Environment.instance.apiBaseUrl, connectTimeout: Duration(seconds: 5), receiveTimeout: Duration(seconds: 10))`
  - Five HTTP methods (`get`, `post`, `patch`, `put`, `delete`) — each wraps the corresponding `_dio` call in try/catch on `DioException`, rethrowing via `_handleDioError`
  - `_handleDioError(DioException)` returns `ApiException` — extracts `message` or `error` from response data when available, maps `connectionTimeout`/`sendTimeout`/`receiveTimeout` to "Connection timeout", `connectionError` to "No internet connection", and the rest to "Network error"; logs every error via `dart:developer` `log()` with name `'HttpClient'`
