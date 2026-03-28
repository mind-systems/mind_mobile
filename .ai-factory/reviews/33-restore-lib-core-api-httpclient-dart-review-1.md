# Code Review — Plan #33: Restore `lib/Core/Api/HttpClient.dart`

**Files Reviewed:** 6 (HttpClient.dart, ApiExeption.dart, Environment.dart, Environment.example.dart, pubspec.yaml, pubspec.lock)
**Risk Level:** 🟡 Medium

### Context Gates

- **ARCHITECTURE.md** — WARN: `HttpClient` sits in `lib/Core/Api/`, consistent with the Architecture's `Core/Api/` layer for "API interfaces + request/response DTOs". No boundary violations.
- **RULES.md** — WARN: "All dependencies must be injected via constructor" — `HttpClient` accepts `List<Interceptor> interceptors` via constructor. Compliant. Not yet wired into `App.dart` (intentionally deferred, no consumer exists).
- **ROADMAP.md** — Phase 5.1 is marked `[x]` complete. Linked correctly.

### Critical Issues

**1. `_handleDioError` will crash on non-Map response bodies** (`HttpClient.dart:64-66`)

```dart
final message =
    e.response?.data['message'] ??
    e.response?.data['error'] ??
    e.message ??
    'Unknown error';
```

When `e.response` is non-null (we're inside the `if (e.response != null)` branch), `data` can be a `String` (HTML error page from nginx 502, plain text), `null`, or any other type — not just a `Map`. Calling `['message']` on a `String` throws `NoSuchMethodError` at runtime. The `??` chain does not protect — the exception occurs before the null-coalescing operator evaluates. This turns every non-JSON server error (502 proxy page, timeout HTML, malformed response) into an unhandled crash instead of a clean `ApiException`.

Fix — guard with a type check:

```dart
final data = e.response?.data;
final message =
    (data is Map ? data['message'] ?? data['error'] : null) ??
    e.message ??
    'Unknown error';
```

This was present in the original code, but since it's being actively re-introduced as new code and will crash the first time a REST consumer hits a non-JSON error, it should be fixed now rather than carried forward.

### Suggestions

None.

### Positive Notes

- Constructor-injected `List<Interceptor>` is a clean adaptation — avoids coupling to a specific auth interceptor that no longer exists.
- Dropping `saveToken`/`clearToken` was the right call — prevents a dual-write path to `jwt_token` storage key.
- Environment values are consistent with the existing gRPC host pattern (`grpc.mind-awake.life` → `api.mind-awake.life`).
- `ApiExeption.dart` preserves the legacy filename, avoiding import breakage in future consumers.
- Static analysis (`flutter analyze`) passes cleanly — zero issues on all changed files.

REVIEW_PASS
