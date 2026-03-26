# Plan: Implement `lib/User/UserGrpcApi.dart`

## Context

Replace the HTTP-based `UserApi` with a gRPC implementation (`UserGrpcApi`) that implements `IUserApi` using three gRPC service stubs (`UserServiceClient`, `StatsServiceClient`, `BreathSessionServiceClient`), then swap the wiring in `App.dart`.

This plan covers roadmap item **2.7** (Replace UserApi with generated stub). It also satisfies **2.11** (Replace StatsApi with generated stub) because `fetchStats()` lives on `IUserApi` — there is no separate `IStatsApi` interface, so no separate `StatsGrpcApi` class is needed. After implementation, both 2.7 and 2.11 should be marked done on the roadmap.

**Follow-up:** Deletion of `lib/Core/Api/UserApi.dart` (the second bullet of roadmap 2.7) is deferred to a separate plan/task — it will be cleaned up alongside other dead HTTP API files when all stubs are migrated.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Implement UserGrpcApi

- [x] **Task 1: Create `lib/User/UserGrpcApi.dart`**
  Files: `lib/User/UserGrpcApi.dart`

  Create a new file that implements `IUserApi`. Follow the same pattern as `AuthGrpcApi` and `BreathSessionGrpcApi` — constructor takes only the service client stubs, each method builds a proto request inline, private `_map*` helpers convert proto responses to domain DTOs.

  Constructor takes three stubs because `IUserApi` spans three gRPC services:
  - `UserServiceClient` — for `updateProfile`
  - `StatsServiceClient` — for `getStats`
  - `BreathSessionServiceClient` — for `getSuggestions`

  Import conventions (match `BreathSessionGrpcApi`):
  - `import '...users.pb.dart' as usersProto;`
  - `import '...users.pbgrpc.dart' show UserServiceClient;`
  - `import '...stats.pb.dart' as statsProto;`
  - `import '...stats.pbgrpc.dart' show StatsServiceClient;`
  - `import '...breath_sessions.pb.dart' as bsProto;`
  - `import '...breath_sessions.pbgrpc.dart' show BreathSessionServiceClient;`

  Note: do **not** import `breath_sessions.pbenum.dart` separately — `breath_sessions.pb.dart` already re-exports it, so `bsProto.TimeOfDay` is accessible through the `bsProto` alias. This matches `BreathSessionGrpcApi` which uses a single proto import for everything.

  Method implementations:

  1. **`updateUser(UpdateUserRequest request)`** — build `usersProto.UpdateProfileRequest(name: request.name, language: request.language)`, call `_userService.updateProfile(...)`, discard the returned `UserDto` (the HTTP version also returns `void`).

  2. **`fetchStats()`** — call `_statsService.getStats(statsProto.GetStatsRequest())`, map `GetStatsResponse` to `UserStatsDTO` via a private `_mapStats` method. Field mapping:
     - `totalSessions` -> `totalSessions`
     - `totalDurationSeconds` -> `totalDurationSeconds`
     - `currentStreak` -> `currentStreak`
     - `longestStreak` -> `longestStreak`
     - `lastSessionDate` -> `lastSessionDate` (use `response.hasLastSessionDate() ? response.lastSessionDate : null` since `UserStatsDTO.lastSessionDate` is nullable but proto defaults to empty string)
     - `maxCompletedComplexity` -> `maxCompletedComplexity` (proto is `double`, DTO is `int` — truncate with `.toInt()`)

  3. **`fetchSuggestions(String timeOfDay)`** — convert the `timeOfDay` string (`"morning"`, `"midday"`, `"evening"` — these are `DayPeriod.queryValue` values) to the proto `bsProto.TimeOfDay` enum via a private `_mapTimeOfDay` helper. Build `bsProto.GetSuggestionsRequest(timeOfDay: ...)`, call `_breathSessionService.getSuggestions(...)`. Map each `BreathSessionDto` in the response's `suggestions` list to `SuggestionDTO` via a private `_mapSuggestion` helper:
     - `id` -> `dto.id`
     - `title` -> `dto.description` (sessions have no separate title; the HTTP endpoint also returns `description` for both fields — see `SuggestionDTO.fromJson` which maps both `title` and `description` from `json['description']`)
     - `description` -> `dto.description`
     - `iconUrl` -> `null` (proto `BreathSessionDto` has no `iconUrl` field; HTTP version also rarely returns it)

  The `_mapTimeOfDay` helper must include a default case — return `bsProto.TimeOfDay.MORNING` for any unrecognized string. This matches the defensive pattern used by other mappers in the codebase (e.g., `_mapStepType` in `BreathSessionGrpcApi` defaults to `StepType.inhale`).

### Phase 2: Wire in App.dart

- [x] **Task 2: Replace `UserApi` with `UserGrpcApi` in `App.dart`**
  Files: `lib/Core/App.dart`

  1. Replace the import `import 'package:mind/Core/Api/UserApi.dart';` with `import 'package:mind/User/UserGrpcApi.dart';`.

  2. Replace the initialization line (line 129):
     ```
     final userApi = UserApi(httpClient);
     ```
     with:
     ```
     final userApi = UserGrpcApi(grpcClient.userService, grpcClient.statsService, grpcClient.breathSessionService);
     ```
     Single line, no trailing commas — per the App.dart style rule.

  No other files change — `UserRepository`, `HomeService`, and all other consumers type against `IUserApi`, so the swap is transparent.
