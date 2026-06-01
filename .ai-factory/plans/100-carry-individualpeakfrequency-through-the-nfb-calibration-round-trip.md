# Plan: Carry `individualPeakFrequency` through the NFB calibration round-trip

## Context
Neiry's SDK exposes `individualFrequency` and `individualPeakFrequency` as two distinct fields, but `NfbCalibrationData` stores only the former and restores neiry's peak from it — corrupting the peak on every reconnect-restore. This milestone adds a dedicated `individualPeakFrequency` field and fixes the local-cache + live-SDK round-trip. Durable server sync is gated on a mind_api proto change (their Phase 29) and is planned but kept inert until the field ships.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Local cache + live-SDK round-trip (ships atomically)

- [x] **Task 1: Add `individualPeakFrequency` field to the model**
  Files: `lib/Bci/Models/NfbCalibrationData.dart`
  Add `final double individualPeakFrequency;` (place it next to `individualFrequency`).
  Add a `required this.individualPeakFrequency` parameter to the const constructor.
  In `toJson`, add the key `'individualPeakFrequency': individualPeakFrequency`.
  In `fromJson`, read it with a backward-compat fallback so existing local cache (and legacy server history) does not break:
  `individualPeakFrequency: ((json['individualPeakFrequency'] ?? json['individualFrequency']) as num).toDouble()`.

- [x] **Task 2: Capture the peak in `startCalibration` mapping** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart` (~line 376, `CalibrationCompleted` → `NfbCalibrationData` mapping)
  Add `individualPeakFrequency: data.individualPeakFrequency,` to the `NfbCalibrationData(...)` construction, reading the distinct SDK field (not `individualFrequency`).

- [x] **Task 3: Restore the peak in `importCalibration`** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart` (~line 407)
  Change the `neiry.IndividualNfbData(...)` construction so `individualPeakFrequency: data.individualPeakFrequency` (currently it duplicates `data.individualFrequency`). Leave `individualFrequency: data.individualFrequency` unchanged.

- [x] **Task 4: Keep `NfbCalibrationGrpcApi` compiling without the proto field** (depends on Task 1)
  Files: `lib/Bci/NfbCalibrationGrpcApi.dart`
  Adding a required constructor param breaks `_recordToDomain`, which constructs `NfbCalibrationData` from generated stubs that do NOT yet expose a peak field. To keep the build green and preserve correct behavior for server-sourced rows, set the new field to the existing-frequency fallback for now:
  `individualPeakFrequency: r.individualFrequency,`.
  Do NOT touch `record()` yet (the request has no peak field). This is intentionally a placeholder consistent with the `fromJson` fallback — Phase 2 replaces it once the proto ships. Add a brief `// TODO(mind_api Phase 29): use r.individualPeakFrequency with the <=0 sentinel rule.` comment at the line so the gated follow-up is discoverable.

### Phase 2: Durable server sync — GATED on mind_api Phase 29 proto change

> Do NOT start this phase until `mind_api` ships `individual_peak_frequency` in `proto/nfb_calibration.proto` (their Phase 29; contract in note 60). Verify the field exists on the wire before regenerating stubs.

- [ ] **Task 5: Sync proto and regenerate stubs** (depends on mind_api Phase 29)
  Files: `proto/nfb_calibration.proto`, `lib/Core/Grpc/generated/nfb_calibration.*` (generated)
  Copy the updated `proto/nfb_calibration.proto` from `mind_api/proto/` into `mind_mobile/proto/` (copy explicitly, no symlink). Confirm field `individual_peak_frequency` (`float`, number 14 on `NfbCalibrationRecord`, number 12 on `RecordNfbCalibrationRequest`). Run `./scripts/gen_proto.sh` to regenerate Dart stubs. Do not regenerate before the field has landed upstream.

- [ ] **Task 6: Send and read the peak over gRPC with the sentinel rule** (depends on Task 5)
  Files: `lib/Bci/NfbCalibrationGrpcApi.dart`
  In `record()`, add `individualPeakFrequency: data.individualPeakFrequency` to `RecordNfbCalibrationRequest(...)`.
  In `_recordToDomain()`, replace the Task 4 placeholder with the `<= 0`-means-absent sentinel rule (proto3 `float` defaults to `0.0`; peak is always ~8–13 Hz, so treat `0.0` as missing):
  `individualPeakFrequency: r.individualPeakFrequency > 0 ? r.individualPeakFrequency : r.individualFrequency`.
  This prevents `refreshFromServer` from overwriting the local cache with a bogus `0.0` peak for legacy rows. Remove the Task 4 TODO comment.

## Commit Plan
- **Commit 1** (after tasks 1-4): "Carry individualPeakFrequency through the NFB calibration local round-trip"
- **Commit 2** (after tasks 5-6, only once mind_api proto ships): "Sync individualPeakFrequency over gRPC with absent-peak sentinel"
