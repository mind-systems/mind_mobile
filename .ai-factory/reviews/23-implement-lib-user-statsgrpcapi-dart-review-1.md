## Code Review Summary

**Files Reviewed:** 7
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md:** WARN — `IStatsApi` lives in `lib/User/` alongside `IUserApi`. This is consistent with the existing layout (stats are user-scoped), but `StatsGrpcApi` is a thin gRPC wrapper, not a domain component — architecturally fine since other `*GrpcApi` classes follow the same placement pattern.
- **RULES.md:** No violations. `App.dart` remains infrastructure-only; `HomeService` stays stateless; all dependencies injected via constructor.
- **ROADMAP.md:** Milestone 2.11 "Replace StatsApi with generated stub" is correctly marked complete.

### Critical Issues

**1. `FakeUserApi` in test has orphan `fetchStats()` override**
File: `test/User/UserRepository_test.dart`, lines 14–30

`FakeUserApi implements IUserApi` still overrides `fetchStats()` and imports `UserStatsDTO`. Since `fetchStats()` was removed from `IUserApi`, the `@override` annotation is now incorrect (`override_on_non_overriding_member` analyzer diagnostic). The code compiles and tests still pass because Dart allows extra methods on a class — but the dead override and unused import should be removed to keep the fake consistent with the interface it implements.

**Fix:** Remove the `fetchStats()` override (lines 18–26), the `UserStatsDTO` import (line 5), and the unused `SuggestionDTO` import only if also unreferenced (line 4 — still used on line 29, keep it).

### Suggestions

None.

### Positive Notes

- Clean extraction: `StatsGrpcApi._mapStats()` is a verbatim copy of the old `UserGrpcApi._mapStats()` — no accidental field changes or type mismatches.
- `GrpcClient.statsService` (line 34 of `GrpcClient.dart`) returns `StatsServiceClient` — type matches `StatsGrpcApi` constructor expectation.
- `App.dart` wiring order is correct: `statsApi` instantiated before the `App._()` constructor, single-line style rule followed.
- `HomeService.fetchStats()` now routes through `statsApi` while `fetchSuggestions()` stays on `userApi` — separation is clean.
- `UserRepository` confirmed to only use `updateUser()` on `IUserApi` (lines 94, 98) — no broken consumer.
- Proto type mapping verified: `maxCompletedComplexity` is `double` in proto → `.toInt()` → `int` in `UserStatsDTO`; `hasLastSessionDate()` guard handles the optional proto field correctly.
