## Code Review Summary

**Files Reviewed:** 14 (across commits `c908c4b` through `4eec711`)
**Risk Level:** 🟡 Medium

### Context Gates

- **ARCHITECTURE.md** — WARN: line 40 shows `Api/` → `GrpcClient + GrpcAuthInterceptor`, but both files live in `lib/Core/Grpc/`, not `lib/Core/Api/`. The `Api/` directory now holds only interfaces (`ISyncApi`, `IPersonalAccessTokenApi`) and DTO models. Misleading for any agent or developer reading the folder structure.
- **RULES.md** — no violations. No module-specific state added to `App.dart`; all dependencies injected via constructor.
- **ROADMAP.md** — OK. Phase 2.4 item checked off. Phase 4.3 items checked off.

### Critical Issues

1. **`docs/core/jwt-authentication.md` — stale `AuthInterceptor` references (Task 5 not implemented)**
   Lines 2–3, 5, and 15 still describe `AuthInterceptor` as the component that attaches tokens and catches 401 errors. The file was partially updated (line 13 now references `AuthGrpcApi` and protobuf for token extraction), but the surrounding paragraphs still describe the Dio-era HTTP flow. The plan explicitly required replacing all `AuthInterceptor` mentions with `GrpcAuthInterceptor` and updating HTTP 401 references to `StatusCode.unauthenticated`.

2. **`docs/core/global-listeners.md` — stale `AuthInterceptor` in chain diagram**
   Line 11: `` `AuthInterceptor` (401) → `LogoutNotifier.triggerLogout()` → ... ``
   Line 13: still references `AuthInterceptor` as "приватный медиатор между `AuthInterceptor` и `UserNotifier`".
   Should reference `GrpcAuthInterceptor` and UNAUTHENTICATED (code 16).

3. **`docs/core/testing.md` — stale infrastructure layer references**
   Line 37: `| **Infrastructure** (`LiveSocketService`, `AuthInterceptor`, `HttpClient`) | Require mocking socket.io / Dio. ... |`
   All three classes are deleted. Should reference `LiveSessionGrpcService`, `GrpcAuthInterceptor`, `GrpcClient` and "gRPC" instead of "socket.io / Dio".

4. **`docs/user/login-flow.md` — stale cross-reference**
   Line 37: `- [JWT Authentication](jwt-authentication.md) — токены, AuthInterceptor, logout по 401`
   Should say `GrpcAuthInterceptor, logout по UNAUTHENTICATED`.

5. **`AGENTS.md` — references 3 deleted files**
   - Line 28: `lib/Core/Api/AuthInterceptor.dart` — file deleted. Should be `lib/Core/Grpc/GrpcAuthInterceptor.dart` with updated purpose.
   - Line 30: `lib/Core/Sync/SyncSocketListener.dart` — file deleted, replaced by `SyncGrpcListener`.
   - Line 31: `lib/Core/Api/SyncApi.dart` — file deleted, replaced by `lib/Core/Sync/SyncGrpcApi.dart`.

6. **`lib/User/LogoutNotifier.dart` line 5 — says "401" instead of UNAUTHENTICATED**
   Doc comment: `[GrpcAuthInterceptor] calls [triggerLogout] on every 401 response.`
   `GrpcAuthInterceptor` catches `GrpcError` with `StatusCode.unauthenticated` (code 16), not HTTP 401. The class name was updated but the error code description was not.

7. **`.ai-factory/DESCRIPTION.md` line 70 — references deleted `ApiException` model**
   `Error handling: \`ApiException\` model, typed notifier events for error propagation`
   `ApiExeption.dart` was deleted with the Dio infrastructure. gRPC errors now propagate as `GrpcError` exceptions. This line is stale.

8. **`.ai-factory/ARCHITECTURE.md` line 40 — `Api/` folder description is inaccurate**
   Shows `Api/` → `GrpcClient + GrpcAuthInterceptor`. Both are in `lib/Core/Grpc/`. The `Api/` folder now contains only interfaces and DTO models. Should read something like `Api/` → `Interfaces + request/response DTOs` or the tree should show the `Grpc/` folder separately.

### Suggestions

None — all findings above should be fixed.

### Positive Notes

- **Clean code removal**: No traces of `AuthInterceptor`, `HttpClient`, or `package:dio` remain in `lib/`. The grep verification confirms zero leftover imports.
- **Correct initialization order in `App.dart`**: `GrpcAuthInterceptor` → `GrpcClient` → all API stubs. Dependencies flow cleanly.
- **`LogoutNotifier` doc comment class reference was updated**: The `[GrpcAuthInterceptor]` linkage is correct (only the error code description needs fixing).
- **`CLAUDE.md` and `.ai-factory/ROADMAP.md`** were properly updated with accurate gRPC terminology.
