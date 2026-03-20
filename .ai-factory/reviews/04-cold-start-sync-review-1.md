# Review: Cold Start Sync

## Scope

`lib/Core/App.dart` — two changes: awaited cold-start sync with timeout, and a post-login auth stream listener.

---

## Critical

### 1. Dead code: `initialUser is AuthenticatedState` is always false

`App.dart:134`

```dart
if (initialUser is AuthenticatedState) {
  await syncEngine.sync().timeout(const Duration(seconds: 5), onTimeout: () {});
}
```

`initialUser` is a `User` (returned by `userRepository.loadUser()` on line 130). `AuthenticatedState` extends `AuthState`, not `User`. The `is` check will always evaluate to `false` — the cold-start sync never executes.

This bug is pre-existing (from the SyncEngine commit), but the current change perpetuates it.

**Fix:**

```dart
if (!initialUser.isGuest) {
  await syncEngine.sync().timeout(const Duration(seconds: 5), onTimeout: () {});
}
```

---

## Minor

### 2. `_isSyncing` flag stays true after timeout fires

`SyncEngine.sync()` sets `_isSyncing = true` on entry and clears it in `finally`. `Future.timeout()` completes the outer future but the inner `sync()` keeps running. If the timeout fires before Dio errors out, `_isSyncing` remains `true` until the inner future's `finally` block runs. During that window (up to ~5 s in a slow-server scenario), subsequent `sync()` calls from `SyncSocketListener` or the auth listener are silently dropped.

In practice the window is short and self-healing. No fix required — just worth being aware of.

---

## Looks good

- Post-login listener (lines 137-140): correct use of `skip(1)` to avoid duplicating cold-start sync, `.where` filter for `AuthenticatedState`, fire-and-forget `listen`. Subscription stays alive because the `BehaviorSubject` holds a reference to its listeners. Matches the `SocketConnectionCoordinator` pattern.
- `.where((s) => s is AuthenticatedState)` is functionally equivalent to `.whereType<AuthenticatedState>()`; either form is fine — the plan originally had `whereType`, the implementation used `.where`. No issue.
- `dart:async` import correctly retained — still needed for `unawaited` on line 125.

---

## Verdict

One critical bug (type check always false). Fix required before merge.

REVIEW_FAIL
