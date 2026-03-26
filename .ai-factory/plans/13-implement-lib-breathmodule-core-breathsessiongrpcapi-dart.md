# Plan: Implement BreathSessionGrpcApi

## Context

Replace the REST-based `BreathSessionApi` with a gRPC implementation that talks to `BreathSessionServiceClient` via the existing `GrpcClient`. The new class implements the same `IBreathSessionApi` interface, mapping between proto messages and domain models internally.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Interface check

- [x] **Task 1: Verify `IBreathSessionApi` signatures against proto shapes**
  Files: `lib/BreathModule/Core/IBreathSessionApi.dart`
  The existing 6 methods map cleanly to gRPC RPCs — no signature changes are needed:
  | Interface method | gRPC RPC | Notes |
  |---|---|---|
  | `create(SaveBreathSessionRequest)` → `BreathSession` | `createSession(CreateSessionRequest)` → `BreathSessionDto` | Fields match; gRPC returns no `isStarred` — domain model defaults to `false` |
  | `update(String id, SaveBreathSessionRequest)` → `BreathSession` | `replaceSession(ReplaceSessionRequest)` → `BreathSessionDto` | PUT semantics match the REST `PUT /breath_sessions/$id` |
  | `delete(String sessionId)` → `void` | `deleteSession(DeleteSessionRequest)` → `DeleteSessionResponse` | Response is discarded |
  | `fetchById(String id)` → `BreathSession` | `getSession(GetSessionRequest)` → `BreathSessionWithStarredDto` | Unwrap `.session` + `.isStarred` into single `BreathSession` |
  | `fetchAll(int page, int pageSize)` → `BreathSessionsListResponse` | `listSessions(ListSessionsRequest)` → `ListSessionsResponse` | Each item is `BreathSessionWithStarredDto`; unwrap the same way |
  | `starSession(StarSessionRequest)` → `void` | `updateSessionSettings(UpdateSessionSettingsRequest)` → `UpdateSessionSettingsResponse` | Map `id` + `starred`; response discarded |

  **Action:** Confirm the signatures are compatible and leave the interface unchanged. If something unexpected is found, update the interface and fix `BreathSessionRepository` call sites accordingly.

### Phase 2: Implementation

- [x] **Task 2: Create `BreathSessionGrpcApi`** (depends on Task 1)
  Files: `lib/BreathModule/Core/BreathSessionGrpcApi.dart`
  Create a new file following the `AuthGrpcApi` pattern (`lib/User/AuthGrpcApi.dart`):
  - Import proto messages with `as proto` alias: `import 'package:mind/Core/Grpc/generated/breath_sessions.pb.dart' as proto;`
  - Import the stub client without alias: `import 'package:mind/Core/Grpc/generated/breath_sessions.pbgrpc.dart';`
  - Constructor takes a single `BreathSessionServiceClient` parameter (no `App.shared` access).
  - No try/catch — error handling is centralized in `GrpcAuthInterceptor`.

  **Mapping helpers** (private methods):
  - `BreathSession _mapSession(proto.BreathSessionDto dto, {bool isStarred = false})` — maps proto → domain. Key conversions:
    - `proto.StepType.INHALE/EXHALE/HOLD` → `StepType.inhale/exhale/hold` (use a `Map` or `switch`)
    - `StepDto.duration` (`double`) → `ExerciseStep.duration` (`int`) via `.round()`
    - `ExerciseDto.restDuration` (`double`) → `ExerciseSet.restDuration` (`int`) via `.round()`
    - `BreathSessionDto.createdAt` (ISO-8601 `String`) → `DateTime.parse(...)`
    - Pass `isStarred` through to `BreathSession` constructor
  - `BreathSession _mapSessionWithStarred(proto.BreathSessionWithStarredDto dto)` — delegates to `_mapSession(dto.session, isStarred: dto.isStarred)`
  - `List<proto.ExerciseDto> _mapExercisesToProto(List<ExerciseSet> exercises)` — maps domain → proto. Key conversions:
    - `ExerciseStep.duration` (`int`) → `.toDouble()` for `StepDto.duration`
    - `ExerciseSet.restDuration` (`int`) → `.toDouble()` for `ExerciseDto.restDuration`
    - `StepType.inhale/exhale/hold` → `proto.StepType.INHALE/EXHALE/HOLD`

  **Method implementations:**
  1. `create` — build `proto.CreateSessionRequest(description:, exercises:, shared:)` from `SaveBreathSessionRequest` fields; call `_service.createSession(...)`; return `_mapSession(response)`
  2. `update` — build `proto.ReplaceSessionRequest(id: id, description:, exercises:, shared:)` from `SaveBreathSessionRequest` fields + the `id` parameter; call `_service.replaceSession(...)`; return `_mapSession(response)`
  3. `delete` — call `_service.deleteSession(proto.DeleteSessionRequest(id: sessionId))`; return nothing
  4. `fetchById` — call `_service.getSession(proto.GetSessionRequest(id: id))`; return `_mapSessionWithStarred(response)`
  5. `fetchAll` — call `_service.listSessions(proto.ListSessionsRequest(page: page, pageSize: pageSize))`; return `BreathSessionsListResponse(data: response.data.map(_mapSessionWithStarred).toList(), total: response.total, page: response.page, pageSize: response.pageSize)`
  6. `starSession` — call `_service.updateSessionSettings(proto.UpdateSessionSettingsRequest(id: request.id, starred: request.starred))`; return nothing

- [x] **Task 3: Wire `BreathSessionGrpcApi` in `App.dart`** (depends on Task 2)
  Files: `lib/Core/App.dart`
  In `App._init()`, replace:
  ```dart
  final breathSessionApi = BreathSessionApi(httpClient);
  ```
  with:
  ```dart
  final breathSessionApi = BreathSessionGrpcApi(grpcClient.breathSessionService);
  ```
  Update imports: add `BreathSessionGrpcApi`, remove `BreathSessionApi` (unless it's still used elsewhere — check first). The downstream `BreathSessionRepository(dao:, api: breathSessionApi)` line stays unchanged since the variable name and type (`IBreathSessionApi`) are the same.
