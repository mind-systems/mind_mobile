# Plan: Implement `lib/User/AuthGrpcApi.dart`

## Context

Replace the REST-based auth API with a gRPC implementation. The interface `IAuthApi` currently depends on REST-specific DTOs (`SendCodeRequest`, `VerifyCodeRequest`, `GoogleAuthRequest`). This milestone updates the interface to use plain parameters matching proto field shapes, creates `AuthGrpcApi` that delegates to `GrpcClient.authService`, and wires it into `App.dart` in place of the HTTP-based `AuthApi`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Update IAuthApi and its callers

- [x] **Task 1: Update `IAuthApi` signatures to match proto shapes**
  Files: `lib/User/IAuthApi.dart`
  Remove imports of REST DTOs (`SendCodeRequest`, `VerifyCodeRequest`, `GoogleAuthRequest`). Change signatures to use plain parameters that mirror proto message fields:
  - `sendCode({required String email, required String locale})` — matches proto `SendCodeRequest(email, locale)`
  - `verifyCode({required String email, required String code, String? language}) → Future<User>` — matches proto `VerifyCodeRequest(email, code, language)`
  - `googleAuth({required String serverAuthCode, String? language, String? redirectUri}) → Future<User>` — matches proto `GoogleAuthRequest(serverAuthCode, language, redirectUri)`
  - `logout() → Future<void>` — proto `LogoutRequest` is empty (identity comes from the JWT in the interceptor), so drop the `User` parameter
  - `clearToken()` — unchanged

- [x] **Task 2: Update `AuthApi` (REST) to match new interface** (depends on Task 1)
  Files: `lib/Core/Api/AuthApi.dart`
  Adapt the existing REST implementation to the new signatures. Each method now receives plain parameters and constructs the REST DTO internally before calling `HttpClient`:
  - `sendCode` → build `SendCodeRequest(email: email, language: locale)` internally (note: REST DTO field is `language`, proto field is `locale` — the DTO's `toJson` already serializes it as `locale`)
  - `verifyCode` → build `VerifyCodeRequest(email: email, code: code, language: language)` internally
  - `googleAuth` → build `GoogleAuthRequest(serverAuthCode: serverAuthCode, language: language, redirectUri: redirectUri)` internally
  - `logout()` → POST to `/auth/logout` with empty body (server identifies user from JWT), then call `_http.clearToken()`

- [x] **Task 3: Update `UserRepository` call sites** (depends on Task 1)
  Files: `lib/User/UserRepository.dart`
  Replace DTO construction at call sites with plain parameters:
  - `sendPasswordlessSignInLink` → `_api.sendCode(email: email, locale: language)` instead of `_api.sendCode(SendCodeRequest(...))`
  - `completePasswordlessSignIn` → `_api.verifyCode(email: email, code: code, language: language)` instead of `_api.verifyCode(VerifyCodeRequest(...))`
  - `authenticateWithGoogle` → `_api.googleAuth(serverAuthCode: serverAuthCode, language: language, redirectUri: redirectUri)` instead of `_api.googleAuth(GoogleAuthRequest(...))`
  - `logout` → `_api.logout()` instead of `_api.logout(currentUser)`
  Remove the REST DTO imports (`SendCodeRequest`, `VerifyCodeRequest`, `GoogleAuthRequest`) from this file.

- [x] **Task 4: Update `FakeAuthApi` in test file** (depends on Task 1)
  Files: `test/User/UserRepository_test.dart`
  The existing `FakeAuthApi implements IAuthApi` uses the old signatures and will fail to compile after Task 1. Update it to match the new interface:
  - `sendCode({required String email, required String locale})` → capture `lastSentEmail = email`
  - `verifyCode({required String email, required String code, String? language})` → capture `lastVerifiedEmail = email`, `lastVerifiedCode = code`
  - `googleAuth({required String serverAuthCode, String? language, String? redirectUri})` → capture `lastGoogleServerAuthCode = serverAuthCode`
  - `logout()` → remove `User` parameter; drop the `loggedOutUser` field and the `loggedOutUser = user` assignment (server identifies the user from the JWT, so there's nothing meaningful to capture)
  - Remove imports of `SendCodeRequest`, `VerifyCodeRequest`, `GoogleAuthRequest` from the test file
  - Fix the logout test assertion: remove `expect(api.loggedOutUser?.id, _authenticatedUser.id)` — replace with a simple boolean flag `logoutCalled = true` and assert `expect(api.logoutCalled, true)`
  - Update the `logout` test call: `await repo.logout(_authenticatedUser)` stays the same (the `UserRepository.logout` method still takes `currentUser` for `clearSession` — only `_api.logout()` lost the parameter)

### Phase 2: Create gRPC implementation and wire it

- [x] **Task 5: Create `AuthGrpcApi`** (depends on Task 1)
  Files: `lib/User/AuthGrpcApi.dart`
  Create `AuthGrpcApi implements IAuthApi`. Constructor takes `AuthServiceClient` (from `grpcClient.authService`) and `FlutterSecureStorage` (for token persistence). The token key is `jwt_token` — same key used by `HttpClient`, `AuthInterceptor`, and `GrpcAuthInterceptor`.
  - `sendCode` → call `_authService.sendCode(proto.SendCodeRequest(email: email, locale: locale))`
  - `verifyCode` → call `_authService.verifyCode(proto.VerifyCodeRequest(email: email, code: code, language: language))`, extract `accessToken` from `AuthResponse` body (gRPC puts the token in the message body, not response headers — see comment in `auth.pb.dart`), save it to `FlutterSecureStorage`, map `AuthResponse.user` (`UserDto`) → domain `User(id:, email:, name:, language:, isGuest: false)`
  - `googleAuth` → same pattern as `verifyCode`: call stub, save token from response body, map `UserDto` → `User`
  - `logout` → call `_authService.logout(proto.LogoutRequest())`, then clear token from storage
  - `clearToken` → delete `jwt_token` from `FlutterSecureStorage`
  Import the generated proto types with a prefix (`import '...auth.pb.dart' as proto`) to avoid name collisions with the REST DTOs and the domain `User` model.
  Note: proto string fields default to `''` (not `null`) when unset. The `UserDto` → `User` mapping should use the proto values as-is since `language: userDto.language` will be `''` rather than `null`, which matches the domain model's existing behavior.

- [x] **Task 6: Wire `AuthGrpcApi` in `App.dart`** (depends on Task 5)
  Files: `lib/Core/App.dart`
  Replace `final authApi = AuthApi(httpClient)` with `final authApi = AuthGrpcApi(grpcClient.authService, const FlutterSecureStorage())`. This requires moving `grpcClient` initialization **before** the `authApi` line (currently it's near the end of `initialize()`). Move `appLifecycleService`, `grpcAuthInterceptor`, and `grpcClient` up — they depend only on `Environment`, `FlutterSecureStorage`, and `logoutNotifier`, all of which are already available at the top of `initialize()`. Add the `AuthGrpcApi` import; the `AuthApi` import can be removed.

## Commit Plan
- **Commit 1** (after tasks 1-6): "Replace REST auth API with gRPC — update IAuthApi to transport-agnostic params, add AuthGrpcApi, wire in App.dart"
