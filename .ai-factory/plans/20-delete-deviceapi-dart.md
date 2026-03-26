# Plan: Delete DeviceApi.dart

## Context
Remove the old REST-based `lib/Core/Api/DeviceApi.dart` now that `DeviceGrpcApi` is fully wired. This file was already deleted as part of plan 19 (Task 4), and no references remain in the source tree — the only residual artifacts are stale Drift build-cache files in `.dart_tool/`. This plan confirms the deletion and cleans up.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Verify and clean up

- [x] **Task 1: Confirm `DeviceApi.dart` is deleted and unreferenced**
  Files: `lib/Core/Api/DeviceApi.dart` (should not exist)
  Verify that `lib/Core/Api/DeviceApi.dart` does not exist on disk. Run a grep across `lib/` for `DeviceApi` to confirm zero remaining imports or string references. If the file or any reference still exists, delete/remove them.

- [x] **Task 2: Remove stale build-cache artifacts**
  Files: `.dart_tool/build/generated/mind/lib/Core/Api/DeviceApi.dart.drift_elements.json`, `.dart_tool/build/generated/mind/lib/Core/Api/DeviceApi.dart.drift_module.json`
  Delete the two orphaned Drift build-cache files left behind in `.dart_tool/build/generated/`. These are not committed to git but can cause confusion during incremental builds.

- [x] **Task 3: Mark roadmap milestone 2.9 "Delete DeviceApi.dart" as done**
  Files: `.ai-factory/ROADMAP.md`
  In the roadmap, change `- [ ] **Delete DeviceApi.dart**` under section 2.9 to `- [x] **Delete DeviceApi.dart**`.
