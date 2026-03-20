# Review 2: Cold Start Sync

## Scope

`lib/Core/App.dart` lines 134-140 — awaited cold-start sync with timeout, and post-login auth stream listener.

---

## Critical

### 1. Dead code: `initialUser is AuthenticatedState` — still present

`App.dart:134`

```dart
if (initialUser is AuthenticatedState) {
  await syncEngine.sync().timeout(const Duration(seconds: 5), onTimeout: () {});
}
```

Flagged in review-1 and not yet fixed. `initialUser` is `User` (from `userRepository.loadUser()` on line 130). `AuthenticatedState` extends `AuthState`, which is an unrelated type hierarchy — `User` can never be `AuthenticatedState`. The condition is always `false` and cold-start sync never runs.

**Fix:**

```dart
if (!initialUser.isGuest) {
  await syncEngine.sync().timeout(const Duration(seconds: 5), onTimeout: () {});
}
```

---

## Rest of the change is correct

- **Post-login listener** (lines 137-140): `skip(1)` correctly avoids replaying the seeded `BehaviorSubject` value. `.where((s) => s is AuthenticatedState)` filters to login transitions only. Fire-and-forget `syncEngine.sync()` is appropriate here since the home screen is already rendered. Subscription lives for the process lifetime via the `BehaviorSubject` reference — matches `SocketConnectionCoordinator` pattern.
- **Timeout wrapper** (line 135): caps the cold-start block at 5 s. `onTimeout: () {}` completes with void silently. `SyncEngine.sync()` already swallows errors internally, so no double-handling. The inner future continues after timeout but `_isSyncing` resets in `finally` — short, self-healing window (noted in review-1, informational only).
- **`dart:async` import** retained correctly — still needed for `unawaited` on line 125.
- **ROADMAP.md** change is metadata only (WebSocket milestone marked skipped).

---

## Verdict

Same critical bug as review-1. Fix the type check, then this is good to merge.

REVIEW_FAIL
