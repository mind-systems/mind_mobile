# Plan: Delete StatsApi.dart

## Context

Remove the old REST-based `StatsApi.dart` file now that `StatsGrpcApi` is fully wired. After investigation, no standalone `StatsApi.dart` file exists — the stats logic originally lived inside `UserApi`/`UserGrpcApi` and was extracted into `StatsGrpcApi` + `IStatsApi` by milestone 2.11. There is nothing to delete.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Verification

- [x] **Task 1: Confirm no `StatsApi.dart` file exists and no stale references remain**
  Files: (none to modify)
  Verify that no file named `StatsApi.dart` (without the `Grpc` prefix) exists anywhere under `lib/`. Also grep for any leftover import or reference to a non-interface `StatsApi` class (excluding `IStatsApi`, `StatsGrpcApi`, and plan/review/roadmap files). If nothing is found, this milestone is already satisfied — mark the roadmap item as done. If a stale file or reference is found, delete the file and remove the import.
