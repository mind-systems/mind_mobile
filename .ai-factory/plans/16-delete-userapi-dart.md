# Plan: Delete UserApi.dart

## Context
`UserGrpcApi` is already wired as the sole `IUserApi` implementation in `App.dart`. The old REST-based `UserApi` at `lib/Core/Api/UserApi.dart` is dead code — nothing imports it. This milestone removes it.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Remove dead file

- [x] **Task 1: Delete `lib/Core/Api/UserApi.dart`**
  Files: `lib/Core/Api/UserApi.dart`
  Delete the file. It implements `IUserApi` via Dio/REST but is no longer instantiated anywhere — `App.dart` line 129 already constructs `UserGrpcApi` instead. No other file imports the concrete `UserApi` class. The interface (`IUserApi`), the DTO (`UpdateUserRequest`), and the response models (`UserStatsDTO`, `SuggestionDTO`) are still used by `UserGrpcApi` and consumers, so they stay.
