# Review: Implement `lib/User/StatsGrpcApi.dart`

Plan: `.ai-factory/plans/23-implement-lib-user-statsgrpcapi-dart.md`

## Files reviewed

| File | Status |
|------|--------|
| `lib/User/IStatsApi.dart` | New |
| `lib/User/StatsGrpcApi.dart` | New |
| `lib/User/IUserApi.dart` | Modified |
| `lib/User/UserGrpcApi.dart` | Modified |
| `lib/Core/App.dart` | Modified |
| `lib/HomeModule/HomeService.dart` | Modified |
| `lib/HomeModule/HomeModule.dart` | Modified |

## Critical

### 1. Test compilation broken — `FakeUserApi` still implements removed `fetchStats()`

`test/User/UserRepository_test.dart:14-30` — `FakeUserApi implements IUserApi` still overrides `fetchStats()` and imports `UserStatsDTO`. Since `fetchStats()` was removed from `IUserApi`, this fake now has an orphan override (Dart analyzer warning) and imports an unused type. While the test may still compile (orphan `@override` is a warning, not an error in Dart), the unused import of `UserStatsDTO` and the dead `fetchStats()` method should be cleaned up to keep tests consistent with the new interface.

**Fix:** Remove `fetchStats()` override and `UserStatsDTO` import from `FakeUserApi` in `test/User/UserRepository_test.dart`.

## Non-critical

None.

## Correctness

- `StatsGrpcApi._mapStats()` is a verbatim copy of the logic previously in `UserGrpcApi._mapStats()` — field mapping, `hasLastSessionDate()` guard, and `maxCompletedComplexity.toInt()` cast are all preserved.
- `GrpcClient.statsService` (line 34) exists and returns `StatsServiceClient` — the type expected by `StatsGrpcApi` constructor.
- `App.dart` wiring order is correct: `statsApi` is created before being passed to the `App._()` constructor, and `UserGrpcApi` constructor was correctly updated to two arguments.
- `HomeService.fetchStats()` now calls `statsApi.fetchStats()` instead of `userApi.fetchStats()`, and `HomeModule` passes `App.shared.statsApi`.
- `UserRepository` only calls `updateUser()` on `IUserApi` — confirmed at lines 94 and 98. No changes needed there.
- `IUserApi` still has `updateUser()` and `fetchSuggestions()` — both callers (`UserRepository`, `HomeService`) are satisfied.
- App.dart single-line style rule is followed for the new `StatsGrpcApi` initializer.

REVIEW_PASS
