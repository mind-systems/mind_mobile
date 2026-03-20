# Route 401 handling through UserNotifier

## Problem

`LogoutNotifier` is a broadcast bus — `AuthInterceptor` calls `triggerLogout()` on every 401, and all subscribers (including `GlobalListeners`) react unconditionally. This causes snackbar spam and a request loop when guest users hit protected endpoints.

## Current flow

```
AuthInterceptor (401)
      │
      ▼
LogoutNotifier.triggerLogout()     ← broadcasts to everyone
      │
 ┌────┴────┐
 ▼         ▼
UserNotifier  GlobalListeners      ← no guard, shows snackbar on every 401
(has guard)
```

## Target flow

```
AuthInterceptor (401)
      │
      ▼
LogoutNotifier                ← private channel (breaks circular dep)
      │
      ▼
UserNotifier.clearSession()
      │
      ├── if GuestState → return (nothing happens)
      │
      └── if Authenticated → emit GuestState + emit sessionExpired
            │
       ┌────┴────┐
       ▼         ▼
 SocketCoord   GlobalListeners
 (already on    (moves to
  userNotifier)  sessionExpiredStream)
```

## Steps

### 1. Add `sessionExpiredStream` to UserNotifier

**File:** `lib/User/UserNotifier.dart`

- Add `PublishSubject<void> _sessionExpiredSubject` field
- Expose as `Stream<void> get sessionExpiredStream`
- In `clearSession()`, after the guard passes and GuestState is emitted, add `_sessionExpiredSubject.add(null)`
- Close in `dispose()`

### 2. Move GlobalListeners from LogoutNotifier to sessionExpiredStream

**File:** `lib/Core/GlobalUI/GlobalListeners.dart`

- Replace constructor parameter `LogoutNotifier logoutNotifier` → `Stream<void> sessionExpiredStream`
- Subscribe to `sessionExpiredStream` instead of `logoutNotifier.stream`
- Remove `LogoutNotifier` import

**File:** `lib/Core/App.dart` (line ~210)

- Pass `sessionExpiredStream: App.shared.userNotifier.sessionExpiredStream` instead of `logoutNotifier`

### 3. Remove logoutNotifier from App public API

**File:** `lib/Core/App.dart`

- Remove `logoutNotifier` from `App._()` constructor and `shared` field
- Keep as local variable in `initialize()` (still needed to wire AuthInterceptor ↔ UserNotifier)

**File:** `lib/User/LogoutNotifier.dart`

- Update docstring: private mediator between AuthInterceptor and UserNotifier, not a public bus
