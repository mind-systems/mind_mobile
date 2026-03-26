# Review: Implement SyncGrpcApi

## Files reviewed

- `lib/Core/Sync/SyncGrpcApi.dart` (new — 87 lines)
- `lib/Core/App.dart` (import swap + line 132 change)
- `lib/Core/Api/SyncApi.dart` (deleted)

## Correctness

**Interface compliance** — `SyncGrpcApi` implements both `ISyncApi` methods (`fetchChanges`, `fetchSessionsBatch`) with matching signatures. No interface change was needed. `SyncEngine` depends only on `ISyncApi`, so it works without modification.

**Proto message mapping (`fetchChanges`)** — The `whichResult()` switch covers all three enum cases (`payload`, `fullResync`, `notSet`), making the switch exhaustive. `SyncEventDto.id` is `Int64` and correctly converted via `.toInt()` to match the domain `ChangeEvent.id` (Dart `int`). `GetChangesRequest.after` correctly wraps the cursor via `Int64(lastEventId)`.

**Proto message mapping (`fetchSessionsBatch`)** — `BatchGetSessionsRequest(ids: ids)` matches the proto shape. Session mapping methods (`_mapSession`, `_mapExercise`, `_mapStep`, `_mapStepType`) are identical to those in `BreathSessionGrpcApi` — verified line by line.

**Name collision avoidance** — The generated `sync.pb.dart` exports a proto `ChangeEvent` class (used for `WatchChanges` streaming). The domain `ChangeEvent` is imported directly from `lib/Core/Api/Models/ChangeEvent.dart`. The proto import uses `as syncProto`, and the `sync.pbgrpc.dart` import uses `show SyncServiceClient`, so no proto `ChangeEvent` leaks into the unqualified namespace. Clean separation.

**App.dart wiring** — Single-line statement style preserved. `SyncGrpcApi` receives `grpcClient.syncService` (`SyncServiceClient`) and `grpcClient.breathSessionService` (`BreathSessionServiceClient`), both confirmed as `late final` getters on `GrpcClient` (lines 35 and 31). Import swap is correct — `SyncApi.dart` removed, `SyncGrpcApi.dart` added.

**No dangling references** — `grep` confirms zero remaining imports of `SyncApi.dart` across the codebase.

## Nit

**Hardcoded `fullResync: true` on line 26** — When the oneof selects `fullResync`, the code returns `SyncResponse(events: [], fullResync: true)` rather than `SyncResponse(events: [], fullResync: response.fullResync)`. In practice the server only selects this oneof branch to signal a true full-resync, so the hardcoded `true` is safe. But using `response.fullResync` would be more precise and match the REST behavior (which passed through the actual boolean value). Not a bug — a server sending `fullResync: false` inside the `fullResync` oneof would be a server-side bug.

## Security

No issues. Auth is handled by `GrpcAuthInterceptor` at the channel level. `SyncGrpcApi` is a pure data-mapping layer with no auth concerns.

## Runtime risks

None identified. The `ISyncApi` contract is unchanged, `SyncEngine` call sites are unaffected, and `GrpcClient.syncService` was already instantiated and available.

REVIEW_PASS
