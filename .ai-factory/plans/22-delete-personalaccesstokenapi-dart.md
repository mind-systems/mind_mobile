# Plan: Delete PersonalAccessTokenApi.dart

## Context

`PersonalAccessTokenGrpcApi` is already wired in `App.dart` (line 130). The old REST/Dio implementation `PersonalAccessTokenApi.dart` is completely unused — no file imports it. This milestone deletes the dead file and removes JSON serialization code in the DTO models that only the deleted REST API called.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Current state

- `PersonalAccessTokenApi.dart` — zero importers (only `App.dart` and `TokenNotifier` reference the interface `IPersonalAccessTokenApi`, not the concrete class).
- `PersonalAccessTokenGrpcApi` constructs `TokenDTO` and `CreateTokenResponse` directly from proto fields — never calls `fromJson`.
- `PersonalAccessTokenGrpcApi` reads `CreateTokenRequest.name` directly — never calls `toJson()`.
- `TokenDTO.fromJson` — only called inside `PersonalAccessTokenApi.dart` (line 15) and internally by `CreateTokenResponse.fromJson`. Dead after file deletion.
- `CreateTokenResponse.fromJson` — only called inside `PersonalAccessTokenApi.dart` (line 21). Dead after file deletion. Note: a same-named factory exists in the generated proto file `auth.pb.dart` — that is a different class in a different namespace, unrelated.
- `CreateTokenRequest.toJson()` — only called inside `PersonalAccessTokenApi.dart` (line 20). Dead after file deletion.
- `IPersonalAccessTokenApi.dart` stays in `lib/Core/Api/` — consistent with other interfaces (`ISyncApi`, `IUserApi`) that remain after their REST impl was deleted.

## Tasks

### Phase 1: Delete dead file and clean up dead code

- [x] **Task 1: Delete `PersonalAccessTokenApi.dart`**
  Files: `lib/Core/Api/PersonalAccessTokenApi.dart`
  Delete the file entirely. It has zero importers — `App.dart` imports `PersonalAccessTokenGrpcApi` (line 22) and the interface `IPersonalAccessTokenApi` (line 23), not this class.

- [x] **Task 2: Remove dead `fromJson` factories and `toJson` from token DTOs**
  Files: `lib/Core/Api/Models/TokenDTO.dart`, `lib/Core/Api/Models/CreateTokenRequest.dart`
  In `TokenDTO.dart`: remove the `factory TokenDTO.fromJson(Map<String, dynamic> json)` constructor (lines 12-16). In `TokenDTO.dart`: remove the `factory CreateTokenResponse.fromJson(Map<String, dynamic> json)` constructor (lines 25-28). In `CreateTokenRequest.dart`: remove the `toJson()` method (line 6). These were only used by the deleted REST API for JSON serialization; the gRPC API constructs objects directly from proto fields.

- [x] **Task 3: Mark roadmap milestone 2.10 as complete**
  Files: `.ai-factory/ROADMAP.md`
  Change the "Delete PersonalAccessTokenApi.dart" line under section 2.10 from `- [ ]` to `- [x]`.
