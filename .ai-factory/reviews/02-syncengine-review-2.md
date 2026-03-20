# Review: 02-syncengine (Round 2)

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

## Review-1 Fixes — Verified

All four issues from round 1 have been correctly addressed:

1. **Unhandled cold-start sync error** — `SyncEngine.sync()` now has `catch (e)` that logs and swallows the error (`SyncEngine.dart:31-32`). The `unawaited()` call in `App.dart:134` is now safe.

2. **`lastEventId` regression** — `processEvents()` now reads `currentId` and only writes when `maxEventId > currentId` (`SyncEngine.dart:53-55`). Concurrent calls can no longer regress the cursor.

3. **Dropped Future in SyncSocketListener** — `processEvents()` call now has `.catchError()` that logs failures (`SyncSocketListener.dart:24-26`).

4. **Created-then-deleted entity in both sets** — `upsertIds.removeAll(deleteIds)` added after the partition loop (`SyncEngine.dart:69`). Deleted entities are no longer batch-refetched.

---

## Full Re-review

**SyncEngine.dart** — Pure Dart, no Flutter/Riverpod imports. `_isSyncing` guard on `sync()` prevents concurrent cold starts. `processEvents()` is intentionally unguarded (socket events must not be blocked by a running cold-start sync); idempotent operations + compare-and-advance on `lastEventId` make concurrent calls safe. Error handling in `sync()` catches all exceptions including network errors. Entity grouping, partitioning, and batch-refetch logic are correct.

**SyncSocketListener.dart** — Subscribes to broadcast stream in constructor; `dispose()` cancels subscription. `whereType<Map<String, dynamic>>()` safely filters malformed entries. `.catchError()` prevents unhandled async errors from fire-and-forget `processEvents()`.

**SyncStateDao.dart** — Table definition with `key` primary key, `insertOnConflictUpdate` for upsert, `getSingleOrNull` for reads. `int.parse` on the stored value is safe since only `setLastEventId(int)` writes to it. `reset()` correctly scopes deletion to the `lastEventId` key only.

**Database.dart** — Schema version bumped 2→3. Migration step `== 2` creates `syncState` table. Step-based loop ensures correct migration for any version path (v1→v3 runs both steps, v2→v3 runs step 2 only). Table and DAO registered in `@DriftDatabase` annotation. Generated code is consistent.

**BreathSessionNotifier.dart** — `invalidate()` extracted cleanly. `_onUserIdChanged` still calls `repository.deleteAll()` before `invalidate()` (auth-specific cleanup preserved). SyncEngine calls `invalidate()` directly after updating Drift (sync-specific path).

**LiveSocketService.dart** — `sync:changed` listener follows identical pattern to `session:state`. Broadcast `StreamController` created, exposed via getter, closed in `dispose()`. Type guard (`data is Map<String, dynamic>`) filters malformed payloads.

**ILiveSocketService.dart** — `syncChangedEvents` added to interface. Test fake implements it with `Stream.empty()`.

**App.dart** — Initialization order correct: SyncEngine after breathSessionNotifier (dependency), SyncSocketListener after liveSocketService (dependency), both before SocketConnectionCoordinator connects the socket (no events missed). Cold-start `sync()` fires only when authenticated. Single-line initializer style followed.

---

## No Issues Found

REVIEW_PASS
