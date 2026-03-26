# Review: Delete StatsApi.dart

## Changes reviewed

| File | Status |
|------|--------|
| `.ai-factory/plans/24-delete-statsapi-dart.md` | New (plan only) |

## Summary

This milestone is a no-op. No `StatsApi.dart` file exists in the repository — the stats-fetching logic was originally part of `UserApi`/`UserGrpcApi` and was extracted into `StatsGrpcApi` + `IStatsApi` during milestone 23. There is no old file to delete.

## Verification

- `StatsApi.dart` does not exist anywhere under `lib/`.
- No bare `StatsApi` references (excluding `IStatsApi`, `StatsGrpcApi`, and `.ai-factory/` docs) appear in `lib/`.
- `StatsGrpcApi` is properly wired in `App.dart` and consumed by `HomeService`.
- `IStatsApi` interface is clean and correctly implemented by `StatsGrpcApi`.

## Issues

None. The only change is the plan file itself. No code was modified.

REVIEW_PASS
