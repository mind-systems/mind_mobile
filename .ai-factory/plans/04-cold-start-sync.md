# Plan: Cold Start Sync

## Context

Ensure `SyncEngine.sync()` completes before the home screen renders when the app launches with an already-authenticated user, and also triggers after a fresh login during a running session. Network errors fall through gracefully — the app proceeds with the stale Drift cache.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Blocking sync at cold start

- [x] **Task 1: Await SyncEngine.sync() before runApp**
  Files: `lib/Core/App.dart`
  Replace the fire-and-forget call on line 134:
  ```dart
  // before
  if (initialUser is AuthenticatedState) unawaited(syncEngine.sync());

  // after
  if (initialUser is AuthenticatedState) {
    await syncEngine.sync().timeout(const Duration(seconds: 5), onTimeout: () {});
  }
  ```
  `SyncEngine.sync()` already catches all exceptions internally (logs and swallows), so the await is safe. The 5-second `timeout` is added as an extra safeguard — if the server accepts the connection but responds slowly (Dio `receiveTimeout` is 10 s), the app won't be stuck on the native splash for too long. On timeout or network error the future completes silently and the app proceeds with whatever is in the Drift cache.
  The `dart:async` import stays — `unawaited` is still used for the `DeviceRepository.ping()` call above.

### Phase 2: Sync on fresh login

- [x] **Task 2: Subscribe to auth state transitions for post-login sync**
  Files: `lib/Core/App.dart`
  Right after the cold-start sync block (after the `if (initialUser is AuthenticatedState)` block), add a stream subscription that triggers sync whenever the user logs in during a running session:
  ```dart
  userNotifier.stream
      .skip(1)
      .whereType<AuthenticatedState>()
      .listen((_) => syncEngine.sync());
  ```
  `skip(1)` drops the initial `BehaviorSubject` emission so the cold-start sync isn't duplicated. `whereType<AuthenticatedState>()` ignores `GuestState` emissions (logout / session expiry). The call is fire-and-forget — the home screen is already visible at this point, and `HomeViewModel` independently reloads its data via the `HomeAuthenticated` event. When `SyncEngine` finishes it calls `breathSessionNotifier.invalidate()`, which refreshes any list screen that is currently listening.
  This follows the same pattern as `SocketConnectionCoordinator` — an app-lifetime subscription created in `App.initialize()` that bridges auth state to an infrastructure service.
