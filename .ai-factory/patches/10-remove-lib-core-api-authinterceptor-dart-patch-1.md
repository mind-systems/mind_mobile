# Patch: 10-remove-lib-core-api-authinterceptor-dart

Fixes all 8 issues from review-1. All changes are documentation-only — no runtime code affected.

---

## Fix 1: `lib/User/LogoutNotifier.dart` — doc comment says "401" instead of UNAUTHENTICATED

**Problem:** Line 5 says `[GrpcAuthInterceptor] calls [triggerLogout] on every 401 response.` — GrpcAuthInterceptor catches `StatusCode.unauthenticated` (gRPC code 16), not HTTP 401.

**Fix:** Replace line 5:

```
OLD: /// [GrpcAuthInterceptor] calls [triggerLogout] on every 401 response.
NEW: /// [GrpcAuthInterceptor] calls [triggerLogout] on every UNAUTHENTICATED (code 16) response.
```

---

## Fix 2: `docs/core/jwt-authentication.md` — stale AuthInterceptor references

**Problem:** Lines 3, 5, 11, 13, and 15 still describe the Dio-era `AuthInterceptor` and HTTP 401 flow despite the migration to gRPC. The doc language is Russian — preserve it.

**Fix:** Replace the entire file content. Changes per paragraph:

- **Line 3** (paragraph 2): `AuthInterceptor выступает прозрачным слоем между приложением и сетью. Он перехватывает каждый исходящий запрос, читает токен из хранилища и молча добавляет его в заголовок, если токен присутствует. Запросы к эндпоинтам аутентификации исключены из этой логики — они не требуют токена, так как используются для его получения. Для всех остальных запросов токен добавляется автоматически, делая авторизацию невидимой для кода, который формирует запросы. Сервисы и репозитории ничего не знают о JWT и просто вызывают методы API, а интерсептор обеспечивает корректную авторизацию на уровне транспорта.`
  →
  `GrpcAuthInterceptor выступает прозрачным слоем между приложением и сетью. Он перехватывает каждый исходящий gRPC-вызов, читает токен из хранилища и молча добавляет его в метаданные запроса, если токен присутствует. Для всех вызовов токен добавляется автоматически, делая авторизацию невидимой для кода, который формирует запросы. Сервисы и репозитории ничего не знают о JWT и просто вызывают методы API, а интерсептор обеспечивает корректную авторизацию на уровне транспорта.`

- **Line 5** (paragraph 3): `Когда токен перестаёт быть валидным, сервер возвращает ответ с кодом 401. Этот момент становится точкой распространения события через систему. AuthInterceptor ловит ошибку в методе обработки ответов, но не принимает решений о том, что делать с состоянием пользователя. Вместо этого он напрямую вызывает метод triggerLogout инжектированного LogoutNotifier — лёгкого event bus, существующего исключительно для передачи сигнала о невалидности сессии.`
  →
  `Когда токен перестаёт быть валидным, сервер возвращает gRPC-ошибку со статусом UNAUTHENTICATED (code 16). Этот момент становится точкой распространения события через систему. GrpcAuthInterceptor ловит ошибку в обработчике ответов, но не принимает решений о том, что делать с состоянием пользователя. Вместо этого он напрямую вызывает метод triggerLogout инжектированного LogoutNotifier — лёгкого event bus, существующего исключительно для передачи сигнала о невалидности сессии.`

- **Line 11** (paragraph 5): `Важно, что ошибка 401 не поглощается интерсептором.`
  →
  `Важно, что ошибка UNAUTHENTICATED не поглощается интерсептором.`

- **Line 13** (paragraph 6, second sentence): `Когда же сервер возвращает 401, вызывается напрямую clearSession`
  →
  `Когда же сервер возвращает UNAUTHENTICATED, вызывается напрямую clearSession`

- **Line 15** (paragraph 7): `AuthInterceptor знает о токенах и HTTP-заголовках, но ничего не знает о состоянии пользователя.`
  →
  `GrpcAuthInterceptor знает о токенах и gRPC-метаданных, но ничего не знает о состоянии пользователя.`

---

## Fix 3: `docs/core/global-listeners.md` — stale AuthInterceptor in chain diagram

**Problem:** Lines 7, 11, and 13 reference `AuthInterceptor` and HTTP 401.

**Fix:** Three replacements:

1. **Line 7** (section header):
   ```
   OLD: ## Обработка 401
   NEW: ## Обработка UNAUTHENTICATED
   ```

2. **Line 11** (chain diagram):
   ```
   OLD: `AuthInterceptor` (401) → `LogoutNotifier.triggerLogout()` → `UserNotifier.clearSession()` → `sessionExpiredStream` → `GlobalListeners` показывает снэкбар
   NEW: `GrpcAuthInterceptor` (UNAUTHENTICATED) → `LogoutNotifier.triggerLogout()` → `UserNotifier.clearSession()` → `sessionExpiredStream` → `GlobalListeners` показывает снэкбар
   ```

3. **Line 13** (two replacements within the paragraph):
   ```
   OLD: `LogoutNotifier` — приватный медиатор между `AuthInterceptor` и `UserNotifier`. Внешний код не должен подписываться на него напрямую. Вся логика принятия решений сосредоточена в `UserNotifier.clearSession()`: он проверяет, что текущее состояние — `AuthenticatedState` (защита от повторных 401 в гостевом режиме), сбрасывает сессию и только тогда эмитит событие в `sessionExpiredStream`.
   NEW: `LogoutNotifier` — приватный медиатор между `GrpcAuthInterceptor` и `UserNotifier`. Внешний код не должен подписываться на него напрямую. Вся логика принятия решений сосредоточена в `UserNotifier.clearSession()`: он проверяет, что текущее состояние — `AuthenticatedState` (защита от повторных UNAUTHENTICATED в гостевом режиме), сбрасывает сессию и только тогда эмитит событие в `sessionExpiredStream`.
   ```

---

## Fix 4: `docs/core/testing.md` — stale infrastructure layer references

**Problem:** Line 37 references three deleted classes (`LiveSocketService`, `AuthInterceptor`, `HttpClient`) and deleted technologies ("socket.io / Dio").

**Fix:** Replace line 37:

```
OLD: | **Infrastructure** (`LiveSocketService`, `AuthInterceptor`, `HttpClient`) | Require mocking socket.io / Dio. Fragile, expensive to maintain, simple logic. |
NEW: | **Infrastructure** (`LiveSessionGrpcService`, `GrpcAuthInterceptor`, `GrpcClient`) | Require mocking gRPC. Fragile, expensive to maintain, simple logic. |
```

---

## Fix 5: `docs/user/login-flow.md` — stale cross-reference

**Problem:** Line 37 says `AuthInterceptor, logout по 401`.

**Fix:** Replace line 37:

```
OLD: - [JWT Authentication](jwt-authentication.md) — токены, AuthInterceptor, logout по 401
NEW: - [JWT Authentication](jwt-authentication.md) — токены, GrpcAuthInterceptor, logout по UNAUTHENTICATED
```

---

## Fix 6: `AGENTS.md` — references 3 deleted files

**Problem:** Lines 28, 30, and 31 reference files that no longer exist.

**Fix:** Three line replacements:

1. **Line 28:**
   ```
   OLD: | `lib/Core/Api/AuthInterceptor.dart` | JWT attach + 401 → logout flow |
   NEW: | `lib/Core/Grpc/GrpcAuthInterceptor.dart` | JWT attach + UNAUTHENTICATED → logout flow |
   ```

2. **Line 30:**
   ```
   OLD: | `lib/Core/Sync/SyncSocketListener.dart` | Bridges Socket.IO `sync:changed` events to SyncEngine |
   NEW: | `lib/Core/Sync/SyncGrpcListener.dart` | Bridges gRPC `WatchChanges` server-stream events to SyncEngine |
   ```

3. **Line 31:**
   ```
   OLD: | `lib/Core/Api/SyncApi.dart` | REST client for `/sync/changes` and `/breath_sessions/batch` |
   NEW: | `lib/Core/Sync/SyncGrpcApi.dart` | gRPC client for sync changes and batch session fetching |
   ```

---

## Fix 7: `.ai-factory/DESCRIPTION.md` — references deleted `ApiException` model

**Problem:** Line 70 references `ApiException` model which was deleted with the Dio infrastructure. gRPC errors propagate as `GrpcError`.

**Fix:** Replace line 70:

```
OLD: - Error handling: `ApiException` model, typed notifier events for error propagation
NEW: - Error handling: `GrpcError` exceptions, typed notifier events for error propagation
```

---

## Fix 8: `.ai-factory/ARCHITECTURE.md` — `Api/` folder description is inaccurate

**Problem:** Line 40 says `Api/` → `GrpcClient + GrpcAuthInterceptor`, but both live in `lib/Core/Grpc/`. The `Api/` folder now contains only interfaces and DTO models.

**Fix:** Replace lines 39-41, adding the `Grpc/` folder:

```
OLD:
│   ├── Database/                   # Drift schema + DAOs
│   ├── Api/                        # GrpcClient + GrpcAuthInterceptor
│   └── GlobalUI/                   # GlobalKeys, GlobalListeners

NEW:
│   ├── Database/                   # Drift schema + DAOs
│   ├── Api/                        # API interfaces + request/response DTOs
│   ├── Grpc/                       # GrpcClient, GrpcAuthInterceptor, LiveSessionGrpcService
│   └── GlobalUI/                   # GlobalKeys, GlobalListeners
```
