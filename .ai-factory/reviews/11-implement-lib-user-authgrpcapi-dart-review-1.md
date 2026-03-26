## Code Review Summary

**Files Reviewed:** 6
**Risk Level:** 🟢 Low

### Context Gates
- **Architecture** (WARN): No violations. `AuthGrpcApi` sits at the Repository/API layer, dependencies injected via constructor, no module-specific state leaks into `App.dart`.
- **Rules** (WARN): All three rules satisfied — no stateful services introduced, no module concerns in `App.dart`, all dependencies constructor-injected.
- **Roadmap** (WARN): Milestone 2.5 "Replace AuthApi with generated stub" is fully addressed — `AuthGrpcApi` wired, old `AuthApi.dart` and REST DTOs deleted.

### Critical Issues
None.

### Suggestions
None.

### Positive Notes

- **Proto field mapping is exact.** Every `AuthGrpcApi` method constructs the proto request with parameter names that match the generated Dart constructors (`SendCodeRequest(email:, locale:)`, `VerifyCodeRequest(email:, code:, language:)`, `GoogleAuthRequest(serverAuthCode:, language:, redirectUri:)`). No field name mismatches.
- **Token key is consistent across all three consumers.** `AuthGrpcApi._tokenKey`, `GrpcAuthInterceptor._tokenKey`, and `UserRepository.loadUser()` all use `'jwt_token'`. `SecureStorage` and `FlutterSecureStorage` instances share the same underlying platform store, so reads/writes are coherent.
- **`IAuthApi` is now transport-agnostic.** The interface uses plain Dart parameters instead of REST DTOs, making it trivially implementable by both the gRPC and test fakes without importing transport-specific types.
- **`_mapUser` handles proto defaults correctly.** Proto string fields default to `''` (not `null`), which matches the domain `User` model's existing convention (e.g., `User.guest()` uses `language: ''`).
- **Test fake updated cleanly.** `FakeAuthApi` matches the new interface, the `logoutCalled` boolean flag is a clear improvement over the old `loggedOutUser` field, and all test assertions are updated to match.
- **`App.dart` initialization order is correct.** `grpcClient` is initialized before `authApi`, and `AuthGrpcApi` receives `grpcClient.authService` (a `late final` getter that creates the stub on first access).

REVIEW_PASS
