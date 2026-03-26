# Plan: Implement `lib/User/StatsGrpcApi.dart`

## Context

Extract the stats-fetching responsibility from `UserGrpcApi` into a dedicated `StatsGrpcApi` class with its own `IStatsApi` interface, following the project's existing pattern of one gRPC API class per proto service. Currently `fetchStats()` lives inside `IUserApi` / `UserGrpcApi` alongside unrelated user and suggestion methods — this task separates it into its own API boundary and rewires all consumers.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Create the stats API interface and implementation

- [x] **Task 1: Create `IStatsApi` interface**
  Files: `lib/User/IStatsApi.dart`
  Create an abstract class `IStatsApi` with a single method `Future<UserStatsDTO> fetchStats()`. Import `UserStatsDTO` from `lib/User/Models/UserStatsDTO.dart`. Follow the same pattern as `IUserApi` and other API interfaces (pure abstract, no implementation details).

- [x] **Task 2: Create `StatsGrpcApi` implementation**
  Files: `lib/User/StatsGrpcApi.dart`
  Create class `StatsGrpcApi implements IStatsApi`. Constructor takes `StatsServiceClient` (from `stats.pbgrpc.dart`). Implement `fetchStats()` by calling `_statsService.getStats(statsProto.GetStatsRequest())` and mapping the response to `UserStatsDTO` via a private `_mapStats()` method. Move the existing mapping logic from `UserGrpcApi._mapStats()` here verbatim — including the `response.hasLastSessionDate()` guard and `maxCompletedComplexity.toInt()` cast.

### Phase 2: Remove stats from UserGrpcApi

- [x] **Task 3: Remove `fetchStats()` from `IUserApi` and `UserGrpcApi`** (depends on Tasks 1-2)
  Files: `lib/User/IUserApi.dart`, `lib/User/UserGrpcApi.dart`
  In `IUserApi`: remove the `fetchStats()` method declaration and the `UserStatsDTO` import. In `UserGrpcApi`: remove the `StatsServiceClient _statsService` field, remove it from the constructor, remove the `fetchStats()` override and `_mapStats()` private method, remove the `stats.pb.dart` and `stats.pbgrpc.dart` imports. The constructor should become `UserGrpcApi(this._userService, this._breathSessionService)` (two arguments instead of three).

### Phase 3: Rewire consumers

- [x] **Task 4: Wire `StatsGrpcApi` in `App.dart`** (depends on Task 3)
  Files: `lib/Core/App.dart`
  Add import for `IStatsApi` and `StatsGrpcApi`. Add a `final IStatsApi statsApi` field to the `App` class and its constructor. In `initialize()`: create `final statsApi = StatsGrpcApi(grpcClient.statsService)` (single-line, no trailing comma). Update the `UserGrpcApi` constructor call to remove `grpcClient.statsService` — it becomes `UserGrpcApi(grpcClient.userService, grpcClient.breathSessionService)`. Pass `statsApi` into the `App._()` constructor. Remove the `// todo debug for stats` comment from the `userApi` field.

- [x] **Task 5: Update `HomeService` and `HomeModule` to use `IStatsApi`** (depends on Task 4)
  Files: `lib/HomeModule/HomeService.dart`, `lib/HomeModule/HomeModule.dart`
  In `HomeService`: add a `final IStatsApi statsApi` constructor parameter. Change `fetchStats()` to call `statsApi.fetchStats()` instead of `userApi.fetchStats()`. Remove the `IUserApi` import if `userApi` is still needed for `fetchSuggestions()` — actually `userApi` is still used for `fetchSuggestions()`, so keep the `IUserApi` import and `userApi` field. Add import for `IStatsApi`. In `HomeModule.buildHomeScreen()`: pass `statsApi: App.shared.statsApi` when constructing `HomeService`.

- [x] **Task 6: Update `UserRepository` constructor** (depends on Task 3)
  Files: `lib/User/UserRepository.dart`, `lib/Core/App.dart`
  Check `UserRepository` — it receives `IUserApi userApi` but only calls `updateUser()`, never `fetchStats()`. No changes needed to `UserRepository` itself since `updateUser()` remains on `IUserApi`. Verify this is the case and confirm no compilation errors.
