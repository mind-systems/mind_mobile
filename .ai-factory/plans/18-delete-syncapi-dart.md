# Plan: Delete SyncApi.dart

## Context

`lib/Core/Api/SyncApi.dart` (the REST/Dio implementation of `ISyncApi`) was already deleted during the SyncGrpcApi implementation (milestone 2.8). `SyncGrpcApi` is fully wired in `App.dart`. This milestone completes the cleanup by removing dead code that only the deleted file used, and marking the roadmap item done.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Current state

- `SyncApi.dart` — already deleted; only stale `.dart_tool/build` cache entries remain (auto-managed, no action needed).
- `SyncGrpcApi.dart` — wired in `App.dart`, constructs `SyncResponse`/`BatchSessionsResponse`/`ChangeEvent` directly from proto objects (never calls `fromJson`).
- `SyncResponse.fromJson` — dead code, zero callers.
- `BatchSessionsResponse.fromJson` — dead code, zero callers.
- `ChangeEvent.fromJson` — **still used** by `SyncSocketListener` (parses Socket.io JSON payloads). Must stay.
- `ISyncApi.dart` stays in `lib/Core/Api/` — consistent with other interfaces (`IPersonalAccessTokenApi`) that remain there after their REST impl is deleted.

## Tasks

### Phase 1: Remove dead code

- [x] **Task 1: Remove dead `fromJson` factories from sync response models**
  Files: `lib/Core/Api/Models/SyncResponse.dart`, `lib/Core/Api/Models/BatchSessionsResponse.dart`
  Remove the `factory SyncResponse.fromJson(...)` constructor from `SyncResponse` and the `factory BatchSessionsResponse.fromJson(...)` constructor from `BatchSessionsResponse`. These were only called by the deleted `SyncApi.dart` for REST JSON deserialization; `SyncGrpcApi` constructs these objects directly from proto fields. Do NOT touch `ChangeEvent.fromJson` — it is still used by `SyncSocketListener`.

- [x] **Task 2: Mark roadmap milestone 2.8 as complete**
  Files: `.ai-factory/ROADMAP.md`
  Change the "Delete SyncApi.dart" line under section 2.8 from `- [ ]` to `- [x]`.
