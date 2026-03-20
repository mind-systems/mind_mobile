# Plan: Sync API Client

## Context

Add the HTTP layer for the sync pipeline: an `ISyncApi` interface with its `SyncApi` Dio implementation, covering the two endpoints needed by SyncEngine (`GET /sync/changes` and `GET /breath_sessions/batch`), plus the three response models that describe their payloads.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Response models

- [x] **Task 1: Create `ChangeEvent` model**
  Files: `lib/Core/Api/Models/ChangeEvent.dart`
  Add a plain Dart class with four fields: `id` (`int`), `entity` (`String`), `refId` (`String`), `action` (`String`). Include a named-parameter constructor with all fields `required` and a `fromJson` factory. Follow the same style as `TokenDTO` — no `toJson` needed (read-only model).

- [x] **Task 2: Create `SyncResponse` model**
  Files: `lib/Core/Api/Models/SyncResponse.dart`
  Add a plain Dart class with two fields: `events` (`List<ChangeEvent>`) and `fullResync` (`bool`). Include a named-parameter constructor (both `required`) and a `fromJson` factory that maps the `events` JSON array through `ChangeEvent.fromJson` and reads `fullResync` as `bool` (default `false` if absent). Import `ChangeEvent`.

- [x] **Task 3: Create `BatchSessionsResponse` model**
  Files: `lib/Core/Api/Models/BatchSessionsResponse.dart`
  Add a plain Dart class with one field: `data` (`List<BreathSession>`). Include a named-parameter constructor and a `fromJson` factory that maps the `data` JSON array through `BreathSession.fromJson`. Import `BreathSession` from `lib/BreathModule/Models/BreathSession.dart`. Follow the same list-deserialization pattern used in `BreathSessionsListResponse.fromJson`.

### Phase 2: Interface and implementation

- [x] **Task 4: Create `ISyncApi` interface** (depends on Tasks 1-3)
  Files: `lib/Core/Api/ISyncApi.dart`
  Declare an abstract class with two methods:
  - `Future<SyncResponse> fetchChanges(int lastEventId)` — corresponds to `GET /sync/changes?after=lastEventId`
  - `Future<BatchSessionsResponse> fetchSessionsBatch(List<String> ids)` — corresponds to `GET /breath_sessions/batch?ids=...`

  Place the file in `lib/Core/Api/` alongside `ITokenApi.dart`. Import response models from `lib/Core/Api/Models/`.

- [x] **Task 5: Create `SyncApi` implementation** (depends on Task 4)
  Files: `lib/Core/Api/SyncApi.dart`
  Concrete class that implements `ISyncApi`. Takes `HttpClient` as its single constructor argument (same pattern as `TokenApi`, `BreathSessionApi`).
  - `fetchChanges` — calls `_http.get('/sync/changes?after=$lastEventId')`, deserializes with `SyncResponse.fromJson(response.data as Map<String, dynamic>)`
  - `fetchSessionsBatch` — joins `ids` with commas, calls `_http.get('/breath_sessions/batch?ids=$joinedIds')`, deserializes with `BatchSessionsResponse.fromJson(response.data as Map<String, dynamic>)`

  Place in `lib/Core/Api/` alongside other concrete API classes.

### Phase 3: DI wiring

- [x] **Task 6: Register `SyncApi` in `App.dart`** (depends on Task 5)
  Files: `lib/Core/App.dart`
  Wire `ISyncApi` into the DI singleton:
  1. Add a `final ISyncApi syncApi;` field to the `App` class and its private constructor
  2. In `initialize()`, after `breathSessionApi` is created, add: `final syncApi = SyncApi(httpClient);`
  3. Pass `syncApi: syncApi` to the `App._()` constructor call
  4. Follow the single-line initializer style rule at the top of the file (no trailing commas, no multi-line)
