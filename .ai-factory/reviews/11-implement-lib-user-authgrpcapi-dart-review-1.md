# Code Review: Implement `lib/User/AuthGrpcApi.dart`

**Plan:** `.ai-factory/plans/11-implement-lib-user-authgrpcapi-dart.md`
**Files reviewed:** 5 modified, 1 new

## Verification

### Proto type alignment

All proto message constructors in `AuthGrpcApi` match the generated `auth.pb.dart` signatures:

- `proto.SendCodeRequest(email:, locale:)` — fields 1,2 ✓
- `proto.VerifyCodeRequest(email:, code:, language:)` — fields 1,2,3 ✓
- `proto.GoogleAuthRequest(serverAuthCode:, language:, redirectUri:)` — fields 1,2,3 ✓
- `proto.LogoutRequest()` — empty message ✓
- `AuthResponse.accessToken` (field 2), `AuthResponse.user` (field 1, `UserDto`) ✓
- `UserDto` fields: `id`, `email`, `name`, `language` — all mapped in `_mapUser` ✓

### Token key consistency

`AuthGrpcApi._tokenKey = 'jwt_token'` matches `HttpClient._tokenKey`, `AuthInterceptor`, `GrpcAuthInterceptor`, and `UserRepository.loadUser`'s storage read. Token written by `AuthGrpcApi` will be picked up by `GrpcAuthInterceptor` for subsequent authenticated calls. ✓

### App.dart dependency ordering

Moved `appLifecycleService`, `grpcAuthInterceptor`, `grpcClient` above `authApi`. Dependencies:
- `AppLifecycleService()` — no deps ✓
- `GrpcAuthInterceptor(storage:, logoutNotifier:)` — `logoutNotifier` initialized on line 121 ✓
- `GrpcClient(host:, port:, isSecure:, detachStream:, interceptors:)` — `Environment.instance`, `appLifecycleService`, `grpcAuthInterceptor` all available ✓
- `AuthGrpcApi(grpcClient.authService, ...)` — `grpcClient` available ✓

### IAuthApi interface update

All three implementors are consistent:
- `IAuthApi` (abstract) — plain params, no REST DTOs ✓
- `AuthApi` (REST, now unused) — constructs DTOs internally ✓
- `AuthGrpcApi` (gRPC, now wired) — constructs proto messages internally ✓
- `FakeAuthApi` (test) — captures params for assertions ✓

### UserRepository call sites

All four call sites updated to pass plain params instead of constructing DTOs:
- `sendPasswordlessSignInLink` → `sendCode(email:, locale:)` ✓
- `completePasswordlessSignIn` → `verifyCode(email:, code:, language:)` ✓
- `authenticateWithGoogle` → `googleAuth(serverAuthCode:, language:, redirectUri:)` ✓
- `logout` → `logout()` (no params) ✓

REST DTO imports (`SendCodeRequest`, `VerifyCodeRequest`, `GoogleAuthRequest`) removed from `UserRepository.dart` and `test/User/UserRepository_test.dart`. ✓

### Error handling

`UserNotifier` catch blocks use generic `catch (e)` — `GrpcError` (thrown by gRPC stubs) will be caught the same way `DioException`/`ApiException` was. No regression. ✓

### Test results

13 of 14 tests pass. The single failure (`loadUser returns existing user from DB`) is **pre-existing** — confirmed by running the test with changes stashed. The test doesn't provision a `jwt_token` in `FakeSecureStorage`, so `loadUser` downgrades the authenticated user to a guest. Not caused by this diff.

## Observations (non-blocking)

1. **`AuthApi` is now dead code** — wired out in `App.dart` but the class remains. Fine to keep as a REST fallback reference, but could be cleaned up in a future pass.

2. **Nullable proto strings** — `language` and `redirectUri` are `String?` in the Dart interface but the proto factory skips setting them when `null`, so they default to `''` on the wire. This is standard protobuf behavior and matches the server's expectations.

3. **`AuthApi.logout` sends empty body** — Changed from `{'id': user.id}` to `{}`. Since `AuthApi` is no longer wired, this has no runtime impact. If re-wired in the future, the backend must accept empty-body logout (it already does, since gRPC `LogoutRequest` is empty and both transports hit the same service layer).

REVIEW_PASS
