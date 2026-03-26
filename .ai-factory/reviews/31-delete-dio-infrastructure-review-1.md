# Review: Delete Dio infrastructure

**Plan:** `.ai-factory/plans/31-delete-dio-infrastructure.md`
**Files reviewed:** 13 changed (3 deleted, 1 new, 9 modified)

---

## Code Deletion (Tasks 1-5) — Clean

- All three Dio files deleted correctly. No remaining `package:dio` imports anywhere in `lib/` or `packages/`.
- `App.dart` — all six removal points handled; the file compiles with clean structure, no dangling references.
- `Environment.example.dart` — `apiBaseUrl` and `wsBaseUrl` fields fully removed from class, constructor, `initDev()`, and `initProd()`. (`Environment.dart` is gitignored — user must update their local copy, which is the expected workflow.)
- `pubspec.yaml` — `dio: ^5.9.0` removed; `pubspec.lock` drops `dio` and `dio_web_adapter`.
- `Api/Models/ApiExeption.dart` deleted; grep confirms zero remaining references to `ApiExeption` or `ApiException` in `lib/`.
- Remaining `lib/Core/Api/` contents (`ISyncApi.dart`, `IPersonalAccessTokenApi.dart`, `Models/`) are correct — all actively imported by gRPC implementations.

## Issues

### 1. `LogoutNotifier.dart` line 5 — stale "401" in doc comment

**Severity:** Low (incorrect doc comment, not a runtime bug)

Line 5 now reads:
```dart
/// [GrpcAuthInterceptor] calls [triggerLogout] on every 401 response.
```

The `[AuthInterceptor]` was correctly updated to `[GrpcAuthInterceptor]`, but "401 response" was not updated. `GrpcAuthInterceptor` intercepts `StatusCode.unauthenticated` (gRPC code 16), not HTTP 401. Should read:

```dart
/// [GrpcAuthInterceptor] calls [triggerLogout] on every UNAUTHENTICATED (code 16) response.
```

### 2. `ARCHITECTURE.md` line 40 — folder comment describes wrong directory

**Severity:** Low (misleading documentation)

The folder structure was changed from:
```
│   ├── Api/                        # Dio client + AuthInterceptor
```
to:
```
│   ├── Api/                        # GrpcClient + GrpcAuthInterceptor
```

But `GrpcClient` and `GrpcAuthInterceptor` live in `lib/Core/Grpc/`, not `lib/Core/Api/`. The `Api/` directory now contains only interfaces (`ISyncApi.dart`, `IPersonalAccessTokenApi.dart`) and request/response models (`Models/`). The comment should describe the actual contents:

```
│   ├── Api/                        # API interfaces + request/response models
│   ├── Grpc/                       # GrpcClient + GrpcAuthInterceptor
```

### 3. `ARCHITECTURE.md` line 170 — stale DI init order

**Severity:** Low (misleading documentation)

The DI Wiring section still reads:
```
Google Sign-In → Database → HTTP client → Auth Interceptor
→ Repositories → Domain Notifiers → DeeplinkRouter
```

Should be updated to reflect current init order:
```
Google Sign-In → Database → gRPC client → gRPC Auth Interceptor
→ Repositories → Domain Notifiers → DeeplinkRouter
```

## Summary

All code changes (deletions, `App.dart` cleanup, `Environment.example.dart`, `pubspec.yaml`) are correct and safe. The three issues above are all low-severity documentation inaccuracies that won't cause runtime failures but will mislead future readers and agent sessions.

REVIEW_PASS
