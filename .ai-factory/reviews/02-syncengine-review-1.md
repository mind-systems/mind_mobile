## Code Review Summary

**Files Reviewed:** 14 (11 new, 3 modified)
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md:** WARN — `SyncEngine` is a domain-layer pure-Dart service with no Flutter/Riverpod imports. Correct placement in `lib/Core/Sync/`. `SyncApi` follows existing API client patterns (`AuthApi`, `BreathSessionApi`). `SyncStateDao` follows existing DAO patterns. All consistent with the layered architecture.
- **RULES.md:** File does not exist. No violations to check.
- **ROADMAP.md:** All four sync milestones (Sync API Client, SyncEngine, WebSocket Sync Listener, Cold Start Sync) are marked complete and match the implemented code.

### Critical Issues

None.

### Suggestions

1. **Cold-start sync blocks app initialization for up to 5 seconds** (`lib/Core/App.dart:134-136`)

   ```dart
   if (!initialUser.isGuest) {
     await syncEngine.sync().timeout(const Duration(seconds: 5), onTimeout: () {});
   }
   ```

   The plan specified fire-and-forget (`unawaited(syncEngine.sync())`), but the implementation blocks `initialize()` with a 5-second timeout. On a bad network the user stares at the splash screen until the timeout fires. The `sync()` method already swallows errors internally, so `unawaited()` is safe. If blocking is intentional (data freshness on first render), consider lowering the timeout to 2-3 seconds — Dio's own `connectTimeout` is 5s, so the outer timeout could fire while Dio is still waiting to connect, leaving a detached Future running in the background anyway.

2. **Query parameters embedded in URL path strings** (`lib/Core/Api/SyncApi.dart:13,19`)

   ```dart
   await _http.get('/sync/changes?after=$lastEventId');
   await _http.get('/breath_sessions/batch?ids=$joinedIds');
   ```

   `HttpClient.get` accepts a `queryParameters` named argument that handles encoding. Using it instead of string interpolation is more consistent with how Dio is designed and would handle edge cases (e.g., special characters in future entity IDs):

   ```dart
   await _http.get('/sync/changes', queryParameters: {'after': lastEventId});
   await _http.get('/breath_sessions/batch', queryParameters: {'ids': joinedIds});
   ```

3. **Concurrent `processEvents` calls are not serialized** (`lib/Core/Sync/SyncEngine.dart:38`)

   `processEvents()` is public and called from both `sync()` (guarded by `_isSyncing`) and `SyncSocketListener` (unguarded). If a socket event arrives mid-sync, two `processEvents` calls interleave at `await` points, potentially issuing redundant `fetchSessionsBatch` calls for overlapping session IDs. The `maxEventId > currentId` check on line 53-56 prevents cursor regression, so no data corruption occurs — but redundant API calls waste bandwidth. A simple guard (similar to `_isSyncing`) or an event queue would eliminate this.

4. **Single malformed event poisons the entire batch** (`lib/Core/Sync/SyncSocketListener.dart:21-24`)

   ```dart
   final events = rawEvents
       .whereType<Map<String, dynamic>>()
       .map(ChangeEvent.fromJson)
       .toList();
   ```

   If any event in the list has a missing or wrongly-typed field, `ChangeEvent.fromJson` throws a `TypeError` during `toList()`, and the `catchError` skips the entire batch. Consider wrapping individual event parsing in a try/catch to skip malformed events while processing the rest.

### Positive Notes

- **Clean concurrency guard in `sync()`** — The `_isSyncing` flag with `try/finally` follows the existing `_isLoading` pattern from `BreathSessionNotifier`. The `maxEventId > currentId` compare-before-set pattern in `processEvents` prevents cursor regression from out-of-order completions.
- **Correct deduplication in `_handleBreathSessionEvents`** — `upsertIds.removeAll(deleteIds)` avoids fetching sessions that were created then deleted in the same batch.
- **Well-ordered wiring in `App.dart`** — `SyncSocketListener` subscribes to `liveSocketService.syncChangedEvents` before `SocketConnectionCoordinator` initiates the connection, so no socket events can be lost during initialization.
- **`invalidate()` extraction in `BreathSessionNotifier`** — Cleanly refactored: `_onUserIdChanged` calls `deleteAll()` then `invalidate()`, while `SyncEngine` calls `invalidate()` directly. Shared logic without duplication.
- **Test updated correctly** — `FakeLiveSocketService` implements the new `syncChangedEvents` getter with `Stream.empty()`, keeping existing tests passing.
- **`SyncStateDao` uses `insertOnConflictUpdate`** — Correct upsert semantics for the key-value store. `reset()` deletes by key rather than truncating the table, leaving room for future sync state keys.
- **Socket `_syncChangedController` is properly closed in `dispose()`** — No stream leak.

REVIEW_PASS
