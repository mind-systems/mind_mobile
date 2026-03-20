# SyncEngine — Mobile Architecture Notes

## Overview

Single sync pipeline for both online (WebSocket) and offline (cold start) scenarios.
SyncEngine is a standalone domain-layer service — no Flutter/Riverpod imports.

## SyncEngine Responsibilities

1. Receive events (from socket directly OR from REST poll on cold start)
2. Group events by entity type
3. Batch-refetch changed entities (`GET /breath_sessions/batch?ids=...`)
4. Apply to Drift cache (upsert for created/updated, delete for deleted)
5. Notify domain notifiers (invalidate/refresh relevant state)
6. Persist `lastEventId` in Drift (same transaction as data updates)

## Two Input Paths, One Processing Pipeline

```
┌──────────────────────────────────────────────────────────┐
│                     SyncEngine                            │
│                                                           │
│  Input A: Socket "sync:changed"                           │
│           events[] delivered in payload                    │
│           → skip REST, go straight to processing          │
│                                                           │
│  Input B: Cold start                                      │
│           GET /sync/changes?after=lastEventId             │
│           → fetch events from REST first                  │
│                                                           │
│  Both paths merge here:                                   │
│           ↓                                               │
│  processEvents(events[]):                                 │
│    Group by entity                                        │
│    Filter: created/updated → refetch list                 │
│            deleted → delete list                          │
│           ↓                                               │
│    Batch refetch: GET /breath_sessions/batch?ids=...      │
│           ↓                                               │
│    Drift transaction:                                     │
│      - upsert fetched entities                            │
│      - delete removed entities                            │
│      - update lastEventId (max from events)               │
│           ↓                                               │
│    Notify BreathSessionNotifier (invalidate)              │
└──────────────────────────────────────────────────────────┘
```

### Request count

```
ONLINE:  socket delivers events  →  batch refetch  →  1 HTTP request
COLD START: /sync/changes        →  batch refetch  →  2 HTTP requests
```

## lastEventId Storage

Stored in Drift (not SharedPreferences) — can be updated in the same transaction as entity changes for atomicity.

New Drift table:
```dart
class SyncState extends Table {
  TextColumn get key => text()();       // "lastEventId"
  TextColumn get value => text()();     // "130"

  @override
  Set<Column> get primaryKey => {key};
}
```

## Idempotency

- Events processed strictly by ascending `id`
- Duplicate events (same entity+refId+action) are harmless — refetch is idempotent
- `lastEventId` only advances forward

## Full Resync

When API responds with `{ fullResync: true }`:
1. Clear all Drift caches (breath sessions, future entities)
2. Reset `lastEventId` to 0
3. Trigger normal paginated fetch (existing refresh flow)

## WebSocket Integration

`LiveSocketService` gets a new listener for `sync:changed` event.
Socket payload contains the events themselves:

```json
{
  "events": [
    { "id": 124, "entity": "breath_session", "refId": "uuid", "action": "updated" }
  ]
}
```

On receive → call `syncEngine.processEvents(events)` directly — no REST fetch needed.
This saves one HTTP request compared to cold start path.

## Cold Start Integration

On app start (after auth), before rendering home screen:
1. `syncEngine.sync()` — fetch and apply any missed changes
2. Then proceed with normal UI loading

If sync fails (network error) — proceed with stale cache. Next successful sync will catch up.

## Notifier Integration

After applying changes, SyncEngine emits a typed event on relevant notifiers:
- `SessionsInvalidated` — already exists on `BreathSessionNotifier`
- Notifier holders (ViewModels) react by refreshing their state from Drift

This avoids SyncEngine knowing about UI — it just signals "data changed" through the domain layer.

## Future Entity Types

SyncEngine is entity-agnostic. When a new entity type appears:
1. Add a handler in the entity-type switch (refetch logic + Drift DAO)
2. Register the corresponding notifier for invalidation
3. Everything else (socket, REST poll, event processing) stays the same
