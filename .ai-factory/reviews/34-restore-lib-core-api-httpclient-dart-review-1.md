# Code Review — Plan #34: Restore `lib/Core/Api/HttpClient.dart`

**Files reviewed:** 6 files (HttpClient.dart, ApiExeption.dart, Environment.example.dart, Environment.dart, pubspec.yaml, pubspec.lock)
**Analyzer:** `flutter analyze` — no issues found

## Verification

- **ApiExeption.dart** — byte-identical to `git show bb04376^:lib/Core/Api/Models/ApiExeption.dart`. Correct.
- **HttpClient.dart** — original code restored with all three plan adaptations applied:
  - `AuthInterceptor` replaced with `List<Interceptor>` — correct.
  - `saveToken()` / `clearToken()` removed — correct, token management lives in `AuthGrpcApi` (writes) and `GrpcAuthInterceptor` (reads). No dual-write path.
  - `FlutterSecureStorage` field and import removed — correct, it was only used by the dropped token methods.
- **Environment.example.dart** — `apiBaseUrl` field added to class, constructor, `initDev()` (`http://localhost:3000`), and `initProd()` (`https://YOUR_PROD_API_URL`). Correct.
- **Environment.dart** — `apiBaseUrl` set to `http://localhost:3000` (dev) and `https://api.mind-awake.life` (prod). Consistent with the gRPC host pattern (`grpc.mind-awake.life`). Correct.
- **pubspec.yaml** — `dio: ^5.9.2` added. Correct.
- **pubspec.lock** — `dio` 5.9.2 + transitive `dio_web_adapter` 2.1.2 resolved. Correct.
- **App.dart wiring** — intentionally deferred per plan. No consumer exists yet. Correct.
- **`jwt_token` ownership** — verified via grep: only `AuthGrpcApi`, `GrpcAuthInterceptor`, and `UserRepository.loadUser()` access this key. `HttpClient` correctly does not touch it.

## Plan inconsistency (non-blocking)

The plan says "with two adaptations" but lists three (Adaptations 1, 2, 3). Additionally, Adaptation 2 adds `FlutterSecureStorage` as a constructor parameter, but Adaptation 3 immediately removes it. The code correctly follows the final intent (no storage), but the plan reads confusingly. Consider removing Adaptation 2 entirely since Adaptation 3 supersedes it.

## Latent note (pre-existing, not introduced)

In `_handleDioError`, `e.response?.data['message']` assumes `data` is a `Map`. If the server returns a non-JSON body (plain string, null), this will throw `NoSuchMethodError` at runtime. This is identical to the original code and not a regression — just worth knowing when the first REST consumer is wired up.

## No issues found

REVIEW_PASS
