# Plan: Route 401 handling through UserNotifier

## Context

`LogoutNotifier` is currently a broadcast bus — every 401 fires to all subscribers (UserNotifier and GlobalListeners) unconditionally, causing snackbar spam for guest users. This milestone makes `LogoutNotifier` a private mediator between `AuthInterceptor` and `UserNotifier`, and introduces `sessionExpiredStream` on `UserNotifier` that only fires when an authenticated session is actually cleared. `GlobalListeners` moves to this new stream so it only shows the snackbar when a real session expiration occurs.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Add sessionExpiredStream to UserNotifier

- [x] **Task 1: Emit sessionExpired event from clearSession()**
  Files: `lib/User/UserNotifier.dart`
  Add a `PublishSubject<void> _sessionExpiredSubject` field and expose it as `Stream<void> get sessionExpiredStream`. In `clearSession()`, after the guard passes (state is not GuestState) and `GuestState(newGuest)` is emitted on `_subject`, add `_sessionExpiredSubject.add(null)`. Close `_sessionExpiredSubject` in `dispose()`, before the existing `_authErrorSubject.close()` call. This is the only place that emits to this stream — `logout()` (user-initiated) does not emit here because there is no unexpected session loss.

### Phase 2: Rewire GlobalListeners

- [x] **Task 2: Switch GlobalListeners from LogoutNotifier to sessionExpiredStream** (depends on Task 1)
  Files: `lib/Core/GlobalUI/GlobalListeners.dart`
  Replace the `LogoutNotifier logoutNotifier` constructor parameter with `Stream<void> sessionExpiredStream`. Update `initState` to subscribe to `sessionExpiredStream` instead of `widget.logoutNotifier.stream`. Rename `_logoutSubscription` to `_sessionExpiredSubscription` for clarity. Remove the `LogoutNotifier` import. The `authErrorStream` parameter and its subscription stay unchanged.

- [x] **Task 3: Update GlobalListeners wiring in App.dart** (depends on Task 2)
  Files: `lib/Core/App.dart`
  In `MyApp.build` (line ~210), change the `GlobalListeners` constructor call: replace `logoutNotifier: App.shared.logoutNotifier` with `sessionExpiredStream: App.shared.userNotifier.sessionExpiredStream`.

### Phase 3: Remove logoutNotifier from App public API

- [x] **Task 4: Make logoutNotifier a local variable in initialize()** (depends on Task 3)
  Files: `lib/Core/App.dart`
  Remove the `logoutNotifier` field from the `App` class (line 60), remove it from the `App._()` constructor (line 79), and remove it from the `shared = App._(...)` call (line 156). The `logoutNotifier` local variable in `initialize()` (line 105) stays — it is still needed to wire `AuthInterceptor` and `UserNotifier`. Remove the `LogoutNotifier` import only if no other reference remains after the field removal (the local variable uses the class, so the import stays).

- [x] **Task 5: Update LogoutNotifier docstring**
  Files: `lib/User/LogoutNotifier.dart`
  Replace the current Russian docstring with an English one that reflects its new role: a private mediator between `AuthInterceptor` (producer) and `UserNotifier` (sole consumer). Mention that external code should use `UserNotifier.sessionExpiredStream` instead of subscribing to `LogoutNotifier` directly.
