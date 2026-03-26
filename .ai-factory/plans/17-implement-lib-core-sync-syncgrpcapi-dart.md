# Plan: Implement SyncGrpcApi

## Context

Replace the Dio-based `SyncApi` with `SyncGrpcApi` that implements `ISyncApi` using the generated `SyncServiceClient` and `BreathSessionServiceClient` gRPC stubs, then wire it in `App.dart`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Implement SyncGrpcApi

- [x] **Task 1: Create `lib/Core/Sync/SyncGrpcApi.dart`**
  Files: `lib/Core/Sync/SyncGrpcApi.dart` (new)

  Create `SyncGrpcApi implements ISyncApi` following the exact pattern from `BreathSessionGrpcApi` and `UserGrpcApi`. Constructor takes two stub clients: `SyncServiceClient` and `BreathSessionServiceClient`.

  **`fetchChanges(int lastEventId)`:**
  - Call `_syncService.getChanges(GetChangesRequest(after: Int64(lastEventId)))`.
  - Switch on `response.whichResult()`:
    - `GetChangesResponse_Result.fullResync` → return `SyncResponse(events: [], fullResync: true)`.
    - `GetChangesResponse_Result.payload` → map `response.payload.events` through a private `_mapEvent(SyncEventDto)` method that returns `ChangeEvent(id: dto.id.toInt(), entity: dto.entity, refId: dto.refId, action: dto.action)`. Return `SyncResponse(events: mappedEvents, fullResync: false)`.
    - `GetChangesResponse_Result.notSet` → return `SyncResponse(events: [], fullResync: false)`.
  - Do NOT pass `limit` — the proto field is optional and SyncEngine does not use pagination. The interface stays unchanged.

  **`fetchSessionsBatch(List<String> ids)`:**
  - Call `_breathSessionService.batchGetSessions(BatchGetSessionsRequest(ids: ids))`.
  - Map `response.sessions` through private `_mapSessionWithStarred` → `_mapSession` → `_mapExercise` → `_mapStep` → `_mapStepType` helper methods, returning `BatchSessionsResponse(data: mappedSessions)`.
  - Duplicate the session-mapping methods from `BreathSessionGrpcApi` (lines 65-101) — each GrpcApi is self-contained per the existing pattern.

  **Imports:**
  - `sync.pb.dart as syncProto`, `sync.pbgrpc.dart show SyncServiceClient`
  - `breath_sessions.pb.dart as bsProto`, `breath_sessions.pbgrpc.dart show BreathSessionServiceClient`
  - Domain models: `ChangeEvent`, `SyncResponse`, `BatchSessionsResponse`, `BreathSession`, `ExerciseSet`, `ExerciseStep`, `StepType`
  - `package:fixnum/fixnum.dart` for `Int64`

  **No error handling** — exceptions propagate to the caller (matches pattern in `BreathSessionGrpcApi`, `AuthGrpcApi`, `UserGrpcApi`).

- [x] **Task 2: Wire `SyncGrpcApi` in `App.dart`** (depends on Task 1)
  Files: `lib/Core/App.dart`

  Replace the `SyncApi` instantiation on line 132:
  ```
  // Remove:
  final syncApi = SyncApi(httpClient);
  // Replace with:
  final syncApi = SyncGrpcApi(grpcClient.syncService, grpcClient.breathSessionService);
  ```

  Update imports:
  - Remove: `import 'package:mind/Core/Api/SyncApi.dart';`
  - Add: `import 'package:mind/Core/Sync/SyncGrpcApi.dart';`
  - Keep: `import 'package:mind/Core/Api/ISyncApi.dart';` (still used for the field type)

  Everything downstream (`SyncEngine`, `SyncSocketListener`) depends only on `ISyncApi` — no other changes needed.

- [x] **Task 3: Delete `SyncApi.dart`** (depends on Task 2)
  Files: `lib/Core/Api/SyncApi.dart` (delete)

  Delete the old Dio-based `lib/Core/Api/SyncApi.dart`. Verify no remaining imports reference it (the only consumer was `App.dart`, updated in Task 2).
