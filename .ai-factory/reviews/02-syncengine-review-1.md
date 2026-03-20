# Review: 02-syncengine (Round 1)

## Files Reviewed

- `lib/Core/Sync/SyncEngine.dart` (new)
- `lib/Core/Sync/SyncSocketListener.dart` (new)
- `lib/Core/Database/ISyncStateDao.dart` (new)
- `lib/Core/Database/SyncStateDao.dart` (new)
- `lib/Core/Database/Database.dart` (modified)
- `lib/Core/Database/Database.g.dart` (regenerated)
- `lib/BreathModule/Core/BreathSessionNotifier.dart` (modified)
- `lib/Core/Socket/ILiveSocketService.dart` (modified)
- `lib/Core/Socket/LiveSocketService.dart` (modified)
- `lib/Core/App.dart` (modified)
- `test/BreathModule/live_session_notifier_test.dart` (modified)

---

## Issues

### 1. Unhandled error on cold-start sync

**File:** `lib/Core/App.dart:134`
**Severity:** Important

```dart
if (initialUser is AuthenticatedState) unawaited(syncEngine.sync());
```

`sync()` has a `try/finally` but no `catch`. If the network is down on cold start, `syncApi.fetchChanges()` throws, and the error becomes an unhandled async error (potentially crashing in debug, logged in release). The plan explicitly says "If sync fails — proceed with stale cache", but the code doesn't catch.

**Fix:** Add error handling to `sync()` itself — wrap the body in try/catch and log the error:

```dart
// SyncEngine.dart — inside sync(), around the existing try/finally
try {
  ...
} catch (e) {
  log('[SyncEngine] sync failed: $e', name: 'SyncEngine');
} finally {
  _isSyncing = false;
}
```

---

### 2. `processEvents()` is unguarded — concurrent calls can regress `lastEventId`

**File:** `lib/Core/Sync/SyncEngine.dart:36-51`
**Severity:** Important

`processEvents()` is public and has no concurrency guard. Two concurrent calls can interleave:

- **Socket rapid-fire:** Two `sync:changed` events arrive in quick succession. Both call `processEvents()` concurrently (since `_onSyncChanged` doesn't await — see issue 3).
- **Socket + cold-start overlap:** `sync()` guards itself with `_isSyncing`, but if a socket event arrives while `sync()` is inside `processEvents()`, the socket listener calls `processEvents()` directly, bypassing the guard.

The risk: batch A (maxId=10) and batch B (maxId=8) run concurrently. If B's `setLastEventId(8)` executes after A's `setLastEventId(10)`, the cursor regresses to 8. The design notes say "`lastEventId` only advances forward", but the code writes unconditionally.

**Fix:** Either:
- (a) Add a `_isSyncing` guard to `processEvents()` too (queue or drop), or
- (b) Make `setLastEventId` a compare-and-advance: read the current value and only write if the new value is strictly greater.

Option (b) is simpler and directly enforces the invariant:

```dart
// SyncEngine.dart
final currentId = await syncStateDao.getLastEventId();
if (maxEventId > currentId) {
  await syncStateDao.setLastEventId(maxEventId);
}
```

---

### 3. Fire-and-forget `processEvents()` in socket listener drops errors silently

**File:** `lib/Core/Sync/SyncSocketListener.dart:24`
**Severity:** Minor

```dart
syncEngine.processEvents(events); // Future not awaited
```

`_onSyncChanged` is a `void` callback, so the returned Future is dropped. If `processEvents()` throws (e.g. batch-refetch fails), the error is unhandled. This is the same class of issue as #1.

**Fix:** Catch and log:

```dart
void _onSyncChanged(Map<String, dynamic> payload) {
  final rawEvents = payload['events'];
  if (rawEvents is! List) return;
  final events = rawEvents
      .whereType<Map<String, dynamic>>()
      .map(ChangeEvent.fromJson)
      .toList();
  syncEngine.processEvents(events).catchError((e) {
    log('[SyncSocketListener] processEvents failed: $e', name: 'SyncSocketListener');
  });
}
```

---

### 4. Created-then-deleted entity ends up in both upsert and delete sets

**File:** `lib/Core/Sync/SyncEngine.dart:54-63`
**Severity:** Minor

If a batch contains `[created(refId=X), deleted(refId=X)]` (sorted by ascending id), the loop puts X in both `upsertIds` AND `deleteIds`. This causes:
- Batch-refetch tries to fetch a deleted entity (API may return it missing or error)
- Then deletes it from Drift

The behavior is technically correct if the batch API gracefully omits missing IDs, but it's fragile and does unnecessary work.

**Fix:** After the loop, remove deleted IDs from the upsert set:

```dart
upsertIds.removeAll(deleteIds);
```

---

## Clean / Correct

- **SyncState Drift table + DAO** — Schema correct, migration step follows existing pattern, `insertOnConflictUpdate` is the right upsert strategy, schema version bump and `Database.g.dart` regeneration are consistent.
- **BreathSessionNotifier.invalidate()** — Clean extraction. `_onUserIdChanged` still calls `repository.deleteAll()` before `invalidate()`, preserving the auth-specific cleanup.
- **LiveSocketService sync:changed listener** — Follows the exact `session:state` pattern. Controller added to `dispose()`. Broadcast stream is correct for multiple potential subscribers.
- **ILiveSocketService / test fake** — Interface updated, test fake returns `Stream.empty()` for `syncChangedEvents`. Tests still pass conceptually.
- **App.dart wiring** — Initialization order is correct: SyncEngine after breathSessionNotifier (dependency), SyncSocketListener after liveSocketService (dependency), both before socket connect (no missed events). Single-line style followed.
- **SyncEngine entity handler pattern** — Entity-type switch with `breath_session` + unknown-entity logging is clean and extensible.
- **SyncEngine `_isSyncing` guard on `sync()`** — Correct try/finally pattern matching `BreathSessionNotifier._isLoading`.

---

## Verdict

Four issues found — two important (#1, #2), two minor (#3, #4). None are show-stoppers that would corrupt data (the sync pipeline is idempotent by design), but #1 will produce unhandled errors in debug mode on network failure, and #2 violates a stated design invariant.

REVIEW_NEEDS_FIXES
