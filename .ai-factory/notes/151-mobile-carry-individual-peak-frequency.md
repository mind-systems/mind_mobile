# Mobile: carry `individualPeakFrequency` through the gRPC client

**Date:** 2026-06-23
**Source:** conversation context

## Key Findings

- The server side is **already done and committed** (mind_api commit `9a294ab`): the source-of-truth proto, entity, migration `1780250925581`, `service.record`, and the `toProtoNfbCalibrationRecord` mapper all carry `individual_peak_frequency`. The only remaining work is the mobile client.
- The mobile proto copy (`proto/nfb_calibration.proto`) is **stale** — it has `individual_peak_frequency_power` but not the plain `individual_peak_frequency` field. So the regenerated stubs lack `individualPeakFrequency`, `record()` cannot send it, and `_recordToDomain` fakes it.
- The domain model (`NfbCalibrationData`) and the SDK→domain mapping (`NeiryBciProvider`, calibration `CalibrationCompleted`) **already populate** `individualPeakFrequency`. The gap is purely the wire (proto copy + `NfbCalibrationGrpcApi` send/read).
- Why it matters: the neiry SDK import (`clCNFBCalibrator_ImportIndividualNFBData`) consumes the full `clCIndividualNFBData` struct including `individualPeakFrequency`. Persisting it is required for a faithful re-import. (Import itself is still unwired — separate concern, out of scope here.)

## Details

### Current state (today)

- `proto/nfb_calibration.proto` — `NfbCalibrationRecord` ends at `upper_frequency = 12`; `RecordNfbCalibrationRequest` ends at `upper_frequency = 11`. No `individual_peak_frequency`.
- `lib/Bci/NfbCalibrationGrpcApi.dart`
  - `record()` (L10-22) sends every calibration float **except** `individualPeakFrequency`.
  - `_recordToDomain()` (L42-43) substitutes `individualPeakFrequency: r.individualFrequency` behind `// TODO(mind_api Phase 29): use r.individualPeakFrequency with the <=0 sentinel rule.`

### Server contract to copy (mind_api source of truth, already shipped)

- `RecordNfbCalibrationRequest`: `float individual_peak_frequency = 12;`
- `NfbCalibrationRecord` (response): `float individual_peak_frequency = 14;`
- Mapper returns `entity.individualPeakFrequency ?? 0` → **null persists as 0 on the wire** (legacy rows / records written before the field existed). This is the `<=0` sentinel the Phase 29 TODO anticipated.

### The change (one atomic milestone)

1. Copy `mind_api/proto/nfb_calibration.proto` → `mind_mobile/proto/nfb_calibration.proto` verbatim (do **not** hand-author the proto — `mind_api/proto/` is the single source of truth).
2. Run `./scripts/gen_proto.sh` to regenerate the Dart stubs.
3. `NfbCalibrationGrpcApi.record` — add `individualPeakFrequency: data.individualPeakFrequency` to the `RecordNfbCalibrationRequest`.
4. `NfbCalibrationGrpcApi._recordToDomain` — replace the faked line with the sentinel rule and drop the Phase 29 TODO:
   ```dart
   individualPeakFrequency: r.individualPeakFrequency > 0
       ? r.individualPeakFrequency
       : r.individualFrequency,
   ```
   `> 0` because the server maps null → 0; a 0 read means "legacy/absent → fall back to base frequency".

### Verify

- `flutter analyze` clean; generated stub `RecordNfbCalibrationRequest` exposes `individualPeakFrequency`.
- After a real calibration, the value sent on `record` matches `data.individualPeakFrequency` from the SDK (not `individualFrequency`).
- A fresh `list()` round-trip returns the same peak frequency that was recorded (not the base-frequency fake); a legacy record (peak = 0) still falls back to `individualFrequency`.

## Guards

- Do not edit the mobile `.proto` by hand — copy from `mind_api/proto/` and regenerate. Never symlink.
- `NfbCalibrationData.fromJson` already has a backward-compatible local-cache fallback (`individualPeakFrequency ?? individualFrequency`) — no change needed in the model or local cache.
- Out of scope: wiring `importCalibration` (the skip-recalibration round-trip is still unwired — no caller). Dropping any other field (power/suppression/bandwidth/normalized/lower/upper) is explicitly **not** part of this task; the SDK import takes the full struct.

## Open Questions

- None for this task. (Separate, deferred: whether to wire `importCalibration` so persisted calibration can skip recalibration; whether the SDK binary actually consumes lower/upper on import — answerable only by neiry or empirical test once import is wired.)
