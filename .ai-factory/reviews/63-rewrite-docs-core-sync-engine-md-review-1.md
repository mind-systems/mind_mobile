## Code Review: Rewrite `docs/core/sync-engine.md`

**Scope:** 3 staged files — 1 new plan, 1 new plan review, 1 rewritten doc. All documentation; no code changes.

### Verification: doc claims vs source code

Every behavioral claim in the rewritten `docs/core/sync-engine.md` was checked against the implementation:

| Doc claim | Source | Verdict |
|-----------|--------|---------|
| `sync()` calls `syncApi.fetchChanges(lastEventId)` wrapping `SyncService/GetChanges` | `SyncEngine.dart:44-45`, `SyncApi.dart:22-23` | Correct |
| `processEvents()` awaits `_activeSyncOp` before processing | `SyncEngine.dart:63-68` | Correct |
| Pipeline: sort by id → group by entity → split upsert/delete (delete wins) → batch 50 → Drift → cursor → invalidate | `SyncEngine.dart:72-121` | Correct |
| `waitForColdStart(bool)` with 5s timeout | `SyncEngine.dart:27-29`, `App.dart:138` | Correct |
| `authStream.skip(1)` re-syncs on subsequent logins | `SyncEngine.dart:20` | Correct |
| `fullResync`: guard `lastEventId != 0`, delete all, reset cursor, invalidate | `SyncEngine.dart:46-54, 123-127` | Correct |
| `SyncGrpcListener` constructor: `SyncServiceClient`, `SyncEngine`, `ISyncStateDao`, `Stream<AuthState>` | `SyncGrpcListener.dart:22-26` | Correct |
| Auth subscription: `AuthenticatedState` → `_startWatching()`, `GuestState` → `_stopWatching()` | `SyncGrpcListener.dart:28-36` | Correct |
| `_startWatching()` reads cursor then opens `watchChanges(afterId:)` | `SyncGrpcListener.dart:42-44` | Correct |
| Proto `ChangeEvent` envelope → `repeated SyncEventDto` → mapped to domain `ChangeEvent` | `SyncGrpcListener.dart:46-51` | Correct |
| `createdAt` discarded in mapping | `SyncGrpcListener.dart:78-84` | Correct |
| Double `_isAuthenticated` check before/after async DAO read | `SyncGrpcListener.dart:41, 43` | Correct |
| 3-second fixed reconnect timer, cancelled by `_stopWatching()` | `SyncGrpcListener.dart:70-75, 63-68` | Correct |
| `ChangeEvent` domain model: `id`, `entity`, `refId`, `action` | `ChangeEvent.dart:1-13` | Correct |
| `ISyncStateDao`: `getLastEventId()`, `setLastEventId()`, `reset()` | `ISyncStateDao.dart:1-5` | Correct |
| Wiring order: `SyncApi` (L126) → `SyncEngine` (L137) → `await waitForColdStart` (L138) → `SyncGrpcListener` (L162) | `App.dart:126-162` | Correct |
| `SyncGrpcListener` created after cold-start completes | `App.dart:138` (`await`) precedes L162 | Correct |
| Both objects live for app lifetime, no explicit dispose called | `App.dart` — no `dispose()` calls found | Correct |

### Cleanup verification

| Removed item | Status |
|-------------|--------|
| `[← ...]` / `[→ ...]` prev/next nav links | Removed |
| `## See Also` section | Removed |
| Socket.IO terms (`SyncSocketListener`, `SocketConnectionCoordinator`, `LiveSocketService`, `sync:changed`, `WebSocket`, `Socket.IO`) | None remain |
| REST terms (`httpClient`, `GET /sync/changes`, `GET /breath_sessions/batch`, `HTTP-запросов`) | None remain |

### Critical issues

None.

### Non-critical observations

None. The doc accurately reflects the current codebase. No factual errors, no stale terminology, no missing behavioral details.

REVIEW_PASS
