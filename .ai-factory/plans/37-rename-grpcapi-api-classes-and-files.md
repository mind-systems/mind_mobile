# Plan: Rename `*GrpcApi` → `*Api` classes and files

## Context

Drop the `Grpc` infix from all seven API implementation classes and their files. The transport protocol is an implementation detail — callers already use interface types (`IAuthApi`, `IUserApi`, etc.), so the concrete class names should simply be `AuthApi`, `UserApi`, etc.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Rename files and classes

- [x] **Task 1: Rename User module API classes**
  Files: `lib/User/AuthGrpcApi.dart` → `lib/User/AuthApi.dart`, `lib/User/UserGrpcApi.dart` → `lib/User/UserApi.dart`, `lib/User/StatsGrpcApi.dart` → `lib/User/StatsApi.dart`, `lib/Core/App.dart`
  Rename each file and the class inside it:
  - `AuthGrpcApi` → `AuthApi` (implements `IAuthApi` — unchanged)
  - `UserGrpcApi` → `UserApi` (implements `IUserApi` — unchanged)
  - `StatsGrpcApi` → `StatsApi` (implements `IStatsApi` — unchanged)

  In `App.dart`, update the three import paths (`package:mind/User/AuthGrpcApi.dart` → `package:mind/User/AuthApi.dart`, same pattern for the other two) and the three constructor calls (`AuthGrpcApi(…)` → `AuthApi(…)`, etc.). The local variable names (`authApi`, `userApi`, `statsApi`) and the `App._` field types (`IAuthApi`, `IUserApi`, `IStatsApi`) stay unchanged.

- [x] **Task 2: Rename BreathSessionGrpcApi**
  Files: `lib/BreathModule/Core/BreathSessionGrpcApi.dart` → `lib/BreathModule/Core/BreathSessionApi.dart`, `lib/Core/App.dart`
  Rename file and class `BreathSessionGrpcApi` → `BreathSessionApi` (implements `IBreathSessionApi` — unchanged). Update the import path and constructor call in `App.dart`.

- [x] **Task 3: Rename SyncGrpcApi**
  Files: `lib/Core/Sync/SyncGrpcApi.dart` → `lib/Core/Sync/SyncApi.dart`, `lib/Core/App.dart`, `AGENTS.md`
  Rename file and class `SyncGrpcApi` → `SyncApi` (implements `ISyncApi` — unchanged). Update the import path and constructor call in `App.dart`. Also update the file path in the `AGENTS.md` Key Entry Points table (`lib/Core/Sync/SyncGrpcApi.dart` → `lib/Core/Sync/SyncApi.dart`).

- [x] **Task 4: Rename PersonalAccessTokenGrpcApi**
  Files: `lib/McpModule/PersonalAccessTokenGrpcApi.dart` → `lib/McpModule/PersonalAccessTokenApi.dart`, `lib/Core/App.dart`
  Rename file and class `PersonalAccessTokenGrpcApi` → `PersonalAccessTokenApi` (implements `IPersonalAccessTokenApi` — unchanged). Update the import path and constructor call in `App.dart`.

- [x] **Task 5: Rename DeviceGrpcApi**
  Files: `lib/Device/DeviceGrpcApi.dart` → `lib/Device/DeviceApi.dart`, `lib/Device/DeviceRepository.dart`, `lib/Core/App.dart`
  Rename file and class `DeviceGrpcApi` → `DeviceApi`. This is the only class without an interface — `DeviceRepository` references the concrete type directly. Update:
  - The import and constructor call in `App.dart`
  - The import in `DeviceRepository.dart` (`package:mind/Device/DeviceGrpcApi.dart` → `package:mind/Device/DeviceApi.dart`)
  - The field type and constructor parameter type in `DeviceRepository` (`DeviceGrpcApi` → `DeviceApi`)

> **Note:** The milestone mentions `BreathModule.dart` but it contains no `GrpcApi` references — no changes needed there.

### Phase 2: Update references

- [x] **Task 6: Update doc reference in jwt-authentication.md**
  Files: `docs/core/jwt-authentication.md`
  The doc (written in Russian) mentions `AuthGrpcApi` by name on line 13. Replace `AuthGrpcApi` → `AuthApi` in that sentence, keeping the surrounding Russian text unchanged.

- [x] **Task 7: Tick off ROADMAP.md milestone**
  Files: `.ai-factory/ROADMAP.md`
  In milestone 6.3, change the checkbox for the `*GrpcApi` → `*Api` rename task from `- [ ]` to `- [x]`.

## Commit Plan
- **Commit 1** (after tasks 1-3): "Rename User, BreathSession, and Sync GrpcApi classes to Api"
- **Commit 2** (after tasks 4-7): "Rename PersonalAccessToken and Device GrpcApi classes to Api, update doc references"
