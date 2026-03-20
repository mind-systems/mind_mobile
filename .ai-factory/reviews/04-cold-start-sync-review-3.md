# Review 3: Cold Start Sync

## Scope

`lib/Core/App.dart` lines 134-140 — awaited cold-start sync with timeout, and post-login auth stream listener. `ROADMAP.md` metadata update.

---

## Critical

None.

---

## Analysis

### Cold-start sync (lines 134-136)

```dart
if (!initialUser.isGuest) {
  await syncEngine.sync().timeout(const Duration(seconds: 5), onTimeout: () {});
}
```

- The type-check bug from reviews 1-2 is fixed. `initialUser` is `User`, `isGuest` is a `bool` field — the condition now evaluates correctly.
- `await` blocks before `runApp()`, keeping the native splash visible during sync. Correct.
- `SyncEngine.sync()` catches all exceptions internally (`catch (e) { log(...) }`), so the await cannot throw.
- The 5-second `timeout` is an extra guard against a slow server (Dio `receiveTimeout` is 10 s). `onTimeout: () {}` completes with void silently.
- Minor: if the timeout fires before the inner future completes, `SyncEngine._isSyncing` stays `true` until the inner future's `finally` block runs. Self-healing window of a few seconds at most. Noted in review-1, informational only.

### Post-login listener (lines 137-140)

```dart
userNotifier.stream
    .skip(1)
    .where((s) => s is AuthenticatedState)
    .listen((_) => syncEngine.sync());
```

- `skip(1)` correctly drops the seeded `BehaviorSubject` value so cold-start sync isn't duplicated.
- `.where((s) => s is AuthenticatedState)` correctly filters to login transitions only — logout / session expiry (`GuestState`) is ignored.
- Fire-and-forget `syncEngine.sync()` is appropriate — the home screen is already visible and `HomeViewModel` reloads independently via `HomeAuthenticated`.
- Subscription lives for the process lifetime via the `BehaviorSubject` holding a reference to its listeners. Matches `SocketConnectionCoordinator` pattern. No leak concern.
- `AuthState` import (line 50) was already present — no new import needed.
- `dart:async` import retained correctly — still needed for `unawaited` on line 125.

### ROADMAP.md

Metadata only — WebSocket Sync Listener marked as skipped (already implemented). No code impact.

---

## Verdict

Previous critical issue resolved. Both changes are correct and consistent with existing patterns.

REVIEW_PASS
