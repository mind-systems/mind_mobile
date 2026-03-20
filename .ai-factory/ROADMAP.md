# Mind Mobile — Roadmap

## Milestones

- [x] **Sync API Client** — add `ISyncApi` + `SyncApi` (Dio); `GET /sync/changes?after=lastEventId`; `GET /breath_sessions/batch?ids=...`; response models: `ChangeEvent`, `SyncResponse`, `BatchSessionsResponse`
- [x] **SyncEngine** — new domain-layer service; fetches changes → groups by entity → batch-refetches → applies to Drift → notifies notifiers; `SyncState` Drift table for `lastEventId` (atomic with data updates); idempotent, order-preserving; handles `fullResync` by clearing cache + triggering paginated fetch; see [note](.ai-factory/notes/sync-engine.md)
- [x] ⚠️ SKIPPED (already implemented) **WebSocket Sync Listener** — `LiveSocketService` listens for `sync:changed` event on `/live`; payload contains events array; passes directly to `SyncEngine.processEvents()` — no REST fetch, straight to batch refetch (1 request instead of 2)
- [x] **Cold Start Sync** — on app start after auth (in `App.shared` init or `UserNotifier` login), call `SyncEngine.sync()` before rendering home screen; graceful fallback on network error (proceed with stale Drift cache)

## Completed

| Milestone | Date |
|-----------|------|
| Personal Access Tokens | 2026-03-17 |
| Time-of-Day Suggestions Integration | 2026-03-19 |
| Time-of-Day Suggestions Widget UI | 2026-03-19 |
