# Review: Create SyncGrpcListener

**Files reviewed:** `lib/Core/Sync/SyncGrpcListener.dart` (new), `lib/Core/App.dart` (modified), `lib/Core/Sync/SyncSocketListener.dart` (deleted)

**Files read for context:** `SyncEngine.dart`, `SyncGrpcApi.dart`, `SocketConnectionCoordinator.dart`, `UserNotifier.dart`, `ISyncStateDao.dart`, `SyncStateDao.dart`, `ChangeEvent.dart`, `sync.pbgrpc.dart`, `sync.pb.dart`

---

## Critical Issues

None.

## Bugs

**1. Double reconnect on gRPC stream error** (`SyncGrpcListener.dart:53-59`)

When a gRPC stream errors and closes, Dart fires both `onError` and `onDone` (because `cancelOnError` defaults to `false`). This calls `_scheduleReconnect()` twice. The second call overwrites `_reconnectTimer` without canceling the first, so the first `Timer` becomes orphaned. Both timers fire ~3s later, producing two concurrent `_startWatching()` calls.

The second call self-heals (it `_stopWatching`s the subscription from the first), so this won't cascade — but it doubles the reconnection work and logs a spurious reconnect attempt.

**Fix:** Cancel the existing timer at the top of `_scheduleReconnect`:

```dart
void _scheduleReconnect() {
    if (!_isAuthenticated) return;
    _reconnectTimer?.cancel();  // ← add this
    log('[SyncGrpcListener] stream ended, reconnecting in 3s', name: 'SyncGrpcListener');
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_isAuthenticated) _startWatching();
    });
}
```

**2. Unhandled async error in `_startWatching`** (`SyncGrpcListener.dart:28-36`)

`_startWatching()` is an `async` method called fire-and-forget from the auth stream listener (line 31). If `syncStateDao.getLastEventId()` throws (e.g., DB corruption), the rejected Future is unhandled — it hits the Zone error handler, which in release mode can crash the app.

**Fix:** Wrap the body of `_startWatching` in try-catch:

```dart
Future<void> _startWatching() async {
    try {
      await _stopWatching();
      if (!_isAuthenticated) return;
      final lastEventId = await syncStateDao.getLastEventId();
      // ... rest of method
    } catch (e) {
      log('[SyncGrpcListener] startWatching failed: $e', name: 'SyncGrpcListener');
      _scheduleReconnect();
    }
}
```

This also provides a natural retry path — if the initial connection fails, it schedules a reconnect.

## Suggestions

None.

## Positive Notes

- Import aliasing (`sync.pb.dart as syncProto`, `show SyncServiceClient`) correctly avoids the `ChangeEvent` name collision — matches the pattern in `SyncGrpcApi.dart`.
- The `_isAuthenticated` guard checks at two `await` boundaries in `_startWatching` (lines 41, 43) prevent a stale async operation from opening a stream after logout.
- `_mapEvent` correctly mirrors `SyncGrpcApi._mapEvent` — same field mapping, same `.toInt()` on `dto.id`.
- Placement in `App.dart` (line 170, after `waitForColdStart`) is correct — the gRPC auth token is cached at this point.
- `_stopWatching` correctly cancels both the reconnect timer and the watch subscription.
- Deletion of `SyncSocketListener` is clean — no remaining imports in the codebase.

REVIEW_PASS
