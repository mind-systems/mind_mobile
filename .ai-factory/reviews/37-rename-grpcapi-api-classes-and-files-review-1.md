# Review: Rename `*GrpcApi` → `*Api` classes and files

## Summary

Pure mechanical rename of 7 `*GrpcApi` classes and files to `*Api`, plus updates to all import sites, `AGENTS.md`, `jwt-authentication.md`, and `ROADMAP.md`.

## Checklist

- [x] All 7 files renamed (`AuthGrpcApi`, `UserGrpcApi`, `StatsGrpcApi`, `BreathSessionGrpcApi`, `SyncGrpcApi`, `PersonalAccessTokenGrpcApi`, `DeviceGrpcApi`)
- [x] All 7 class names renamed inside each file
- [x] Constructor names match new class names
- [x] `App.dart` — all 7 import paths updated, all 7 constructor calls updated
- [x] `App.dart` — field types unchanged (use interface types `IAuthApi`, `IUserApi`, etc.)
- [x] `DeviceRepository.dart` — import, field type, and constructor parameter type updated (`DeviceGrpcApi` → `DeviceApi`)
- [x] No old `*GrpcApi.dart` files remain on disk
- [x] No stale `GrpcApi` references in `lib/` or `test/`
- [x] `AGENTS.md` — `SyncGrpcApi.dart` → `SyncApi.dart` in Key Entry Points table
- [x] `docs/core/jwt-authentication.md` — `AuthGrpcApi` → `AuthApi` (Russian text preserved)
- [x] `.ai-factory/ROADMAP.md` — milestone 6.3 checkbox ticked

## Critical Issues

None.

## Observations

- Remaining `GrpcApi` mentions exist only in `.ai-factory/` historical plans and reviews — these are archival and should not be modified.
- `interface implements` clauses are unchanged — all 6 interfaced classes still implement the same `I*Api` interfaces.
- `DeviceApi` remains the only class without an interface; `DeviceRepository` correctly references the concrete type.
- No behavioral changes — only identifiers and file paths changed.

REVIEW_PASS
