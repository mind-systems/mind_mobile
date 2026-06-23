# Plan: Carry `individualPeakFrequency` through `NfbCalibrationGrpcApi`

## Context
Wire the `individual_peak_frequency` calibration field across the mobile gRPC boundary so a recorded peak frequency is persisted server-side and read back faithfully (instead of being faked from `individualFrequency`).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Proto sync

- [x] **Task 1: Copy the updated proto from the source of truth**
  Files: `proto/nfb_calibration.proto`
  Replace `mind_mobile/proto/nfb_calibration.proto` with a verbatim copy of `mind_api/proto/nfb_calibration.proto`. The only difference is two new lines: `float individual_peak_frequency = 14;` in `NfbCalibrationRecord` and `float individual_peak_frequency = 12;` in `RecordNfbCalibrationRequest`. Do NOT hand-author the field — `mind_api/proto/` is the single source of truth. Never symlink. Copy the whole file so the mobile snapshot stays byte-identical to the server contract.

- [x] **Task 2: Regenerate Dart gRPC stubs** (depends on Task 1)
  Files: `lib/Core/Grpc/generated/nfb_calibration.pb*.dart`
  Run `./scripts/gen_proto.sh` from `mind_mobile/`. This cleans `lib/Core/Grpc/generated/` and regenerates all stubs. Confirm the regenerated `RecordNfbCalibrationRequest` and `NfbCalibrationRecord` now expose an `individualPeakFrequency` accessor.

### Phase 2: Client wiring

- [x] **Task 3: Send `individualPeakFrequency` on record** (depends on Task 2)
  Files: `lib/Bci/NfbCalibrationGrpcApi.dart`
  In `record()` (L10-22), add `individualPeakFrequency: data.individualPeakFrequency,` to the `RecordNfbCalibrationRequest` constructor (alongside the other `individual*` fields). The domain model `NfbCalibrationData` already exposes `individualPeakFrequency`.

- [x] **Task 4: Read back `individualPeakFrequency` with the sentinel rule** (depends on Task 3)
  Files: `lib/Bci/NfbCalibrationGrpcApi.dart`
  In `_recordToDomain()` (L42-43), remove the `// TODO(mind_api Phase 29): ...` comment and replace the faked assignment with:
  ```dart
  individualPeakFrequency: r.individualPeakFrequency > 0
      ? r.individualPeakFrequency
      : r.individualFrequency,
  ```
  The `> 0` sentinel handles legacy/absent records: the server maps null → 0 via `?? 0`, so a 0 read means "fall back to base `individualFrequency`". Leave every other field mapping unchanged.

## Out of Scope
- Wiring `importCalibration` (still no caller).
- `NfbCalibrationData.fromJson` local-cache fallback — already backward-compatible, no change.
- Dropping or altering any other calibration field (power/suppression/bandwidth/normalized/lower/upper) — the SDK import consumes the full struct.

## Verify
- `flutter analyze` is clean.
- On a real calibration, the value sent on `record` equals `data.individualPeakFrequency` (not `individualFrequency`).
- A fresh `list()` round-trip returns the recorded peak frequency; a legacy record (peak = 0) still falls back to `individualFrequency`.

(4 tasks — single commit at the end: "Carry individualPeakFrequency through NfbCalibrationGrpcApi")
