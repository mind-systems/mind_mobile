# Plan: Add `NfbCalibrationGrpcApi` + wire remote sync in `NfbCalibrationRepository`

## Context
Wrap the generated `NfbCalibrationServiceClient` in a thin domain-facing `NfbCalibrationGrpcApi`, then extend `NfbCalibrationRepository` to fire-and-forget sync each successfully recorded calibration to the backend after local persist. Local cache remains the source of truth for reads (`history`/`latestValid`); the remote `list()` method is exposed for future restore flows but not invoked from the repository in this milestone. Prerequisite milestone 89 (proto stubs present in `lib/Core/Grpc/generated/nfb_calibration.*`) is confirmed complete.

Note: the generated `NfbCalibrationServiceClient` is **not yet exposed on `GrpcClient`** — only the proto stubs were regenerated in milestone 89, so this plan adds the late-init field on `GrpcClient` alongside the new api/repository changes.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Expose the gRPC service client

- [x] **Task 1: Add `nfbCalibrationService` to `GrpcClient`**

### Phase 2: Add the API wrapper

- [x] **Task 2: Create `NfbCalibrationGrpcApi`** (depends on Task 1)

### Phase 3: Wire remote sync into the repository

- [x] **Task 3: Inject `NfbCalibrationGrpcApi` into `NfbCalibrationRepository` and fire-and-forget sync on `record()`** (depends on Task 2)

### Phase 4: Wire the api at the app composition root

- [x] **Task 4: Construct `NfbCalibrationGrpcApi` in `App.dart` and pass it to the repository** (depends on Tasks 1 & 3)

### Phase 5: Sanity check

- [x] **Task 5: Run `flutter analyze`** (depends on Task 4)

## Notes
- No tests (per Settings).
- No commits — global rule requires explicit user permission.
- `flutter analyze` result: 7 pre-existing info warnings, no new errors.

<!-- orchestrator-sessions
planner: b16b7ae4-926f-4fca-a785-47bd9c138830
elapsed: 438
implementer: 353b3803-614d-4b14-aba4-7e7a483b77f4
-->
