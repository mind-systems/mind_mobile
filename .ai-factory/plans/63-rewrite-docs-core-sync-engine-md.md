# Plan: Rewrite `docs/core/sync-engine.md`

## Context

Replace the outdated Socket.IO/REST sync documentation with the current gRPC architecture. The codebase has already been fully migrated — `SyncSocketListener`, `SocketConnectionCoordinator`, and `LiveSocketService` no longer exist. The real-time path is now `SyncGrpcListener` subscribing to a gRPC server-streaming call (`SyncService/WatchChanges`), and the cold-start path uses a gRPC unary call (`SyncService/GetChanges`).

## Settings
- Testing: no
- Logging: no
- Docs: yes (this milestone IS the doc rewrite)

## Language

Neighboring docs in `docs/core/` (notifier-pattern.md, module-system.md, global-listeners.md) are written in Russian. Match that language for the rewrite.

## Tasks

### Phase 1: Rewrite

- [x] **Task 1: Rewrite `docs/core/sync-engine.md` with gRPC architecture**
  Files: `docs/core/sync-engine.md`

  Replace the entire file content. The new doc must cover the sections below, in Russian, matching the prose style of `docs/core/notifier-pattern.md` (descriptive, behavior-focused, no method/field tables that just copy the code).

  **Remove before writing:**
  - The `[← ...]` / `[→ ...]` prev/next navigation links at line 1
  - The `## See Also` section at the end
  - All Socket.IO terminology: `SyncSocketListener`, `SocketConnectionCoordinator`, `LiveSocketService`, `sync:changed`, `WebSocket`, `Socket.IO`, `connect()`
  - All REST terminology: `httpClient`, `GET /sync/changes`, `GET /breath_sessions/batch`, `HTTP-запросов`

  **Section-by-section guide for the new content:**

  1. **Intro paragraph** — the app syncs data via two gRPC paths: a unary call on cold start and a server-streaming call for real-time pushes. Both feed into `SyncEngine`, which keeps Drift in sync with the server.

  2. **Architecture diagram** — replace the old ASCII diagram with:
     ```
     SyncApi (gRPC unary)              SyncGrpcListener (gRPC server-streaming)
       SyncService/GetChanges            SyncService/WatchChanges
              │                                 │
              │                          maps SyncEventDto → ChangeEvent
              │                                 │
              ▼                                 ▼
            ┌─────────────────────────────────────┐
            │            SyncEngine               │
            │  fetchChanges → group → batch → DB  │
            └─────────────────────────────────────┘
                            │
                            ▼
                BreathSessionNotifier.invalidate()
     ```

  3. **SyncEngine section** — describe the two entry points:
     - `sync()` — cold start / login. Calls `syncApi.fetchChanges(lastEventId)` (wraps `SyncService/GetChanges` unary call). Handles `fullResync` flag (clears Drift, resets cursor). Processes events through the shared pipeline.
     - `processEvents(events)` — called by `SyncGrpcListener`. Waits for any in-flight `sync()` to finish before processing (guards via `_activeSyncOp`).
     - Shared pipeline: group by entity → split upserts/deletes (delete wins) → batch-fetch upserts in chunks of 50 via `SyncApi.fetchSessionsBatch()` (wraps `BreathSessionService/BatchGetSessions`) → apply to Drift → advance cursor → invalidate notifier.

  4. **Cold Start Sync section** — on app init, `syncEngine.waitForColdStart()` is called with a 5-second timeout. Also, `SyncEngine` subscribes to `authStream` internally — on each subsequent `AuthenticatedState` (login), it calls `sync()` automatically (skips the first emission via `.skip(1)`).

  5. **Full Resync section** — keep the existing logic description (server responds with `fullResync: true` → if `lastEventId != 0`, clear all sessions, reset cursor, don't refetch — pagination will reload data naturally).

  6. **SyncGrpcListener section** (replaces the old `SyncSocketListener` section) — describe:
     - Constructor takes `SyncServiceClient`, `SyncEngine`, `ISyncStateDao`, `Stream<AuthState> authStream`
     - Subscribes to `authStream`: on `AuthenticatedState` → `_startWatching()`, on `GuestState` → `_stopWatching()`
     - `_startWatching()`: reads `lastEventId` from DAO, opens `syncService.watchChanges(WatchChangesRequest(afterId: lastEventId))`. The server first sends a catchup batch (events after the cursor), then streams new events as they occur. Each proto `ChangeEvent` envelope contains `repeated SyncEventDto` — mapped to domain `ChangeEvent` list and passed to `syncEngine.processEvents()`.
     - Double-checks `_isAuthenticated` before and after the async DAO read to guard against logout during the gap.
     - On stream error or `onDone` → `_scheduleReconnect()`: fixed 3-second `Timer`, re-calls `_startWatching()` if still authenticated. `_stopWatching()` cancels any pending reconnect timer.

  7. **Data models section** — describe `ChangeEvent` (domain model: `id`, `entity`, `refId`, `action`) and note that it is mapped from the proto `SyncEventDto` (which also has a `createdAt` field that is discarded). Mention the proto `ChangeEvent` envelope (wraps `repeated SyncEventDto` — the server coalesces rapid changes into a single envelope). Keep cursor storage description (`SyncState` Drift table, `ISyncStateDao`).

  8. **Optimization table** — replace HTTP/Socket.IO references:

     | Scenario | gRPC calls | Details |
     |----------|-----------|---------|
     | Real-time (streaming) | 1 | Only batch-refetch (unary) |
     | Cold start | 2 | `GetChanges` (unary) + batch-refetch (unary) |
     | No changes | 1 (cold start) / 0 (streaming) | Empty event list — no refetch |

  9. **Wiring section** — show the actual `App.dart` initialization order:
     ```
     SyncApi(grpcClient.syncService, grpcClient.breathSessionService)
       → SyncEngine(syncApi, syncStateDao, breathSessionDao, breathSessionNotifier, authStream: userNotifier.stream)
         → waitForColdStart (blocks up to 5s if authenticated)
       → SyncGrpcListener(syncService, syncEngine, syncStateDao, authStream: userNotifier.stream)
     ```
     Note that `SyncGrpcListener` is created after cold-start completes, so the streaming subscription only starts once the initial cursor is established. Both objects live for the entire app lifetime — no explicit dispose.

  **Reference files for accuracy:**
  - `lib/Core/Sync/SyncGrpcListener.dart` — streaming listener implementation
  - `lib/Core/Sync/SyncEngine.dart` — engine with `sync()` and `processEvents()`
  - `lib/Core/Sync/SyncApi.dart` — gRPC wrapper (`fetchChanges`, `fetchSessionsBatch`)
  - `lib/Core/Api/Models/ChangeEvent.dart` — domain model
  - `lib/Core/App.dart` (lines ~126–162) — wiring order
  - `lib/Core/Grpc/generated/sync.pb.dart` — proto message types
