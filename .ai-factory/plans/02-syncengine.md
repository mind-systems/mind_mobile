# Plan: SyncEngine

## Context

Add a domain-layer `SyncEngine` service that receives change events (from WebSocket or REST poll), groups them by entity, batch-refetches fresh data, applies it atomically to the Drift cache, and notifies domain notifiers. Stores `lastEventId` in a new Drift table so the sync cursor is transactionally consistent with the data it describes.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Drift schema — SyncState table and DAO

- [x] **Task 1: Add SyncState table and bump schema version**
  Files: `lib/Core/Database/Database.dart`
  Add a `SyncState` Drift table with two `TextColumn`s: `key` (primary key) and `value`. Register it in the `@DriftDatabase(tables: [...])` annotation. Add a `SyncStateDao` to the `daos:` list. Bump `schemaVersion` to `3`. Add a migration step in `onUpgrade` for `step == 2` that creates the `syncState` table (follows the existing `step == 1` pattern for `breathSessions`).

- [x] **Task 2: Create ISyncStateDao interface**
  Files: `lib/Core/Database/ISyncStateDao.dart`
  Define an abstract class `ISyncStateDao` with three methods:
  - `Future<int> getLastEventId()` — returns the stored value for key `lastEventId`, parsed as `int`, or `0` if absent.
  - `Future<void> setLastEventId(int eventId)` — upserts the row for key `lastEventId`.
  - `Future<void> reset()` — deletes the `lastEventId` row (used during full resync).

- [x] **Task 3: Implement SyncStateDao**
  Files: `lib/Core/Database/SyncStateDao.dart`
  Create as a `part of 'Database.dart'` file. Annotate with `@DriftAccessor(tables: [SyncState])`. Extend `DatabaseAccessor<Database>` with the generated `_$SyncStateDaoMixin`. Implement `ISyncStateDao`. `getLastEventId` queries by `key.equals('lastEventId')`, returns `int.parse(row.value)` or `0`. `setLastEventId` uses `insertOnConflictUpdate`. `reset` deletes the row with that key. Add `part 'SyncStateDao.dart';` to `Database.dart`.

- [x] **Task 4: Run build_runner to regenerate Drift code**
  Command: `flutter pub run build_runner build`
  After modifying the Database schema (new table, new DAO, new schema version), the generated `Database.g.dart` must be regenerated. This is a prerequisite for all subsequent tasks that touch the database.

### Phase 2: SyncEngine core service

- [x] **Task 5: Create SyncEngine**
  Files: `lib/Core/Sync/SyncEngine.dart`
  Pure Dart class (no Flutter/Riverpod imports). Constructor takes: `ISyncApi syncApi`, `ISyncStateDao syncStateDao`, `IBreathSessionDao breathSessionDao`, `BreathSessionNotifier breathSessionNotifier`. Internal `bool _isSyncing` guard prevents concurrent execution (same pattern as `_isLoading` in `BreathSessionNotifier`).

  Implement two public methods:

  **`Future<void> sync()`** — cold-start path:
  1. Read `lastEventId` from `syncStateDao`.
  2. Call `syncApi.fetchChanges(lastEventId)`.
  3. If `response.fullResync` is `true`, call `_handleFullResync()` and return.
  4. If `response.events` is empty, return.
  5. Call `processEvents(response.events)`.

  **`Future<void> processEvents(List<ChangeEvent> events)`** — shared pipeline (called by both `sync()` and socket listener):
  1. If events is empty, return.
  2. Sort events by `id` ascending (order-preserving).
  3. Group events by `entity` field using a `Map<String, List<ChangeEvent>>`.
  4. For each entity group, call the appropriate entity handler. Initially only `breath_session` is supported — call `_handleBreathSessionEvents(events)`. Unknown entities are skipped (logged).
  5. Compute `maxEventId` from the processed events.
  6. Call `syncStateDao.setLastEventId(maxEventId)`.

  **`_handleBreathSessionEvents(List<ChangeEvent> events)`**:
  1. Partition events: `deleted` actions go into a delete list (extract `refId`s), `created`/`updated` go into an upsert list (extract `refId`s). Deduplicate refIds (a session may appear in multiple events).
  2. If upsert list is non-empty: call `syncApi.fetchSessionsBatch(upsertIds)` to get fresh `BreathSession` objects. Call `breathSessionDao.saveSessions(response.data)`.
  3. If delete list is non-empty: call `breathSessionDao.deleteSession(id)` for each deleted id.
  4. Emit `SessionsInvalidated()` on `breathSessionNotifier` so downstream ViewModels refresh from Drift.

  **`_handleFullResync()`**:
  1. `breathSessionDao.deleteAllSessions()`
  2. `syncStateDao.reset()`
  3. Emit `SessionsInvalidated()` on `breathSessionNotifier` — this tells the UI to re-fetch from scratch via the existing paginated flow.

- [x] **Task 6: Expose invalidation method on BreathSessionNotifier**
  Files: `lib/BreathModule/Core/BreathSessionNotifier.dart`
  Add a public `void invalidate()` method that emits a new state with `lastEvent: SessionsInvalidated()` and clears `byId`/`order`. This is what SyncEngine calls after applying changes. The existing `_onUserIdChanged` already does this inline — extract the shared logic into `invalidate()` and call it from both places. Keep `_onUserIdChanged` calling `repository.deleteAll()` before `invalidate()` as it does today (that deletion is auth-specific, not sync-related).

### Phase 3: Socket integration

- [x] **Task 7: Add sync:changed listener to LiveSocketService**
  Files: `lib/Core/Socket/LiveSocketService.dart`, `lib/Core/Socket/ILiveSocketService.dart`
  Add a new `StreamController<Map<String, dynamic>>` for sync events and expose it as `Stream<Map<String, dynamic>> get syncChangedEvents` on `ILiveSocketService`. In `connect()`, register a listener on the `/live` socket for the `sync:changed` event (same pattern as `session:state`). On receive, parse the payload and push it to the stream controller. Close the controller in `dispose()`.

- [x] **Task 8: Create SyncSocketListener**
  Files: `lib/Core/Sync/SyncSocketListener.dart`
  Pure Dart class. Constructor takes `ILiveSocketService liveSocketService` and `SyncEngine syncEngine`. On construction, subscribes to `liveSocketService.syncChangedEvents`. The listener parses the incoming `Map<String, dynamic>` payload — extracts the `events` list, converts each entry to a `ChangeEvent` via `ChangeEvent.fromJson()`, and calls `syncEngine.processEvents(events)`. Stores the `StreamSubscription` and provides a `dispose()` method to cancel it.

### Phase 4: Wiring and cold-start integration

- [x] **Task 9: Wire SyncEngine and SyncSocketListener into App.dart**
  Files: `lib/Core/App.dart`
  Add fields for `SyncEngine` and `SyncSocketListener` to the `App` class.
  In `initialize()`, after `breathSessionNotifier` is created (line 125) and before `appSettingsNotifier`:
  1. Create `SyncEngine(syncApi: syncApi, syncStateDao: db.syncStateDao, breathSessionDao: db.breathSessionDao, breathSessionNotifier: breathSessionNotifier)`.
  After `liveSocketService` is created (line 146):
  2. Create `SyncSocketListener(liveSocketService: liveSocketService, syncEngine: syncEngine)`.
  Pass both to the `App._()` constructor. Follow existing single-line initializer style (no trailing commas, no multi-line).

- [x] **Task 10: Trigger cold-start sync after auth**
  Files: `lib/Core/App.dart`
  After `BreathSessionNotifier` is initialized and the user is loaded, if the user is authenticated (`initialUser is AuthenticatedState`), call `unawaited(syncEngine.sync())` — fire-and-forget, same pattern as `DeviceRepository.ping()`. If sync fails, the app proceeds with stale cache; the next socket-driven sync or app restart will catch up. No UI blocking.

## Commit Plan
- **Commit 1** (after tasks 1-4): "Add SyncState Drift table with DAO and regenerate schema"
- **Commit 2** (after tasks 5-6): "Implement SyncEngine domain service with event processing pipeline"
- **Commit 3** (after tasks 7-8): "Add sync:changed socket listener and wire to SyncEngine"
- **Commit 4** (after tasks 9-10): "Wire SyncEngine into App.dart with cold-start sync"
