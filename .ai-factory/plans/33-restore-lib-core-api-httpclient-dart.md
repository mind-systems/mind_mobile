# Plan: Restore `lib/Core/Api/HttpClient.dart`

## Context

Re-add the Dio-based HTTP client that was deleted in commit `bb04376`. This restores `HttpClient` (wrapping Dio with `get`/`post`/`patch`/`put`/`delete` and structured error handling) and `ApiException`, so the app has a REST transport alongside the existing gRPC layer.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Dependency and model

- [ ] **Task 1: Add Dio dependency**
  Files: `pubspec.yaml`
  Run `flutter pub add dio` (use `/usr/local/bin/flutter pub add dio`). This adds `dio` to `pubspec.yaml` and updates `pubspec.lock`.

- [ ] **Task 2: Restore `ApiException` model**
  Files: `lib/Core/Api/Models/ApiExeption.dart`
  Re-create the file with the original content (note: the filename keeps the legacy typo `ApiExeption.dart` to match historical imports). The class implements `Exception` with fields `message` (String), `statusCode` (int?), and `data` (dynamic), plus a `toString()` override that includes the status code when present.

### Phase 2: HTTP client and environment

- [ ] **Task 3: Add `apiBaseUrl` to Environment** (depends on Task 1)
  Files: `lib/Core/Environment.dart`, `lib/Core/Environment.example.dart`
  Add a `final String apiBaseUrl` field to `Environment`. Add it to the constructor, and set values in both `initDev()` and `initProd()`. In `Environment.example.dart` use placeholder values (`https://YOUR_DEV_API_URL`, `https://YOUR_PROD_API_URL`). In `Environment.dart` use the real values — dev: `http://localhost:3000`, prod: `https://api.mind-awake.life` (matching the existing gRPC host pattern).

- [ ] **Task 4: Restore `HttpClient`** (depends on Tasks 1, 2, 3)
  Files: `lib/Core/Api/HttpClient.dart`
  Re-create the Dio wrapper class. Restore it from the original code with one adaptation: the constructor originally took `AuthInterceptor authInterceptor` (a Dio-specific auth interceptor that was also deleted). Since that class does not exist in the current codebase and the milestone does not ask to restore it, change the constructor parameter to accept `List<Interceptor> interceptors` (from `package:dio/dio.dart`) and add them all via `_dio.interceptors.addAll(interceptors)`. This keeps the class usable without coupling it to a specific interceptor implementation. Remove the `AuthInterceptor` import. Keep everything else identical to the original:
  - `_dio` initialized with `BaseOptions(baseUrl: Environment.instance.apiBaseUrl, connectTimeout: 5s, receiveTimeout: 10s)`
  - Five HTTP methods (`get`, `post`, `patch`, `put`, `delete`) each catching `DioException` and rethrowing via `_handleDioError`
  - `saveToken` / `clearToken` using `FlutterSecureStorage` with key `jwt_token`
  - `_handleDioError` that converts `DioException` to `ApiException` with status code, message extraction from response body (`message` or `error` fields), and timeout/connection-error mapping
