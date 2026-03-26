# Review: Delete UserApi.dart

## Changes reviewed
- `lib/Core/Api/UserApi.dart` — deleted (33 lines)
- `.ai-factory/plans/16-delete-userapi-dart.md` — new plan file (not application code)

## Verification

### No remaining references to the concrete class
- Grep for `UserApi` (excluding `IUserApi` and `UserGrpcApi`) across `lib/` returns zero matches.
- Grep for the import path `Core/Api/UserApi` returns only plan/roadmap files — no application code.
- Tests in `test/User/UserRepository_test.dart` use `IUserApi` (the interface) and a local `FakeUserApi` — unaffected.

### Replacement is already wired
- `App.dart:129` constructs `UserGrpcApi` as the sole `IUserApi` implementation.
- `UserRepository` receives it via the `userApi` named parameter at line 137.
- `HomeService` receives it via `App.shared.userApi` (typed as `IUserApi`).

### Shared dependencies are still alive
- `IUserApi` (interface) — used by `UserGrpcApi`, `UserRepository`, `HomeService`, `App.dart`, tests.
- `UpdateUserRequest` — used by `IUserApi`, `UserGrpcApi`, `UserRepository`.
- `UserStatsDTO`, `SuggestionDTO` — used by `IUserApi`, `UserGrpcApi`, `HomeService`.
- `HttpClient` — used by many other API classes (`SyncApi`, `DeviceApi`, `PersonalAccessTokenApi`, etc.).

None of these are orphaned by this deletion.

### Runtime impact
None. The deleted class was not instantiated anywhere. No migration, no config change, no type mismatch.

## Issues found
None.

REVIEW_PASS
