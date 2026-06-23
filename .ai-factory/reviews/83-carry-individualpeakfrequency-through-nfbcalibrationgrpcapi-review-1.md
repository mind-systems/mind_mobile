# Code Review: Carry `individualPeakFrequency` through `NfbCalibrationGrpcApi`

**Plan:** `83-carry-individualpeakfrequency-through-nfbcalibrationgrpcapi.md`
**Scope reviewed:** `git diff HEAD` + `git status` — proto copy, regenerated stubs, and the two `NfbCalibrationGrpcApi` edits.

## What changed
1. `proto/nfb_calibration.proto` — added `individual_peak_frequency = 14` (response) and `= 12` (request).
2. `lib/Core/Grpc/generated/nfb_calibration.pb.dart` + `.pbjson.dart` — regenerated stubs.
3. `lib/Bci/NfbCalibrationGrpcApi.dart` — send the field on `record`; read it back with the `> 0` sentinel on `_recordToDomain`.

## Verification

### Proto is a verbatim copy (Task 1)
`diff mind_api/proto/nfb_calibration.proto mind_mobile/proto/nfb_calibration.proto` → **identical**. The single source-of-truth rule is honored; no hand-authoring, no symlink. Field tags (14 / 12) match the server contract and collide with nothing.

### Generated stubs are internally consistent (Task 2)
- Response `NfbCalibrationRecord`: new accessor is `@TagNumber(14)`, storage index 13 (`$_getN(13)`, `$_setFloat(13)`, `$_has(13)`). It is appended last in `BuilderInfo` after `createdAt` (tag 13 / index 12), so the storage index is correct. `clearIndividualPeakFrequency()` correctly uses the tag (`$_clearField(14)`).
- Request `RecordNfbCalibrationRequest`: new accessor is `@TagNumber(12)`, storage index 11 (`$_getN(11)`), appended after `upperFrequency` (tag 11 / index 10) — correct.
- `.pbjson.dart` descriptors and base64 blobs both add the `individual_peak_frequency` entry at tags 14 / 12 with proto type `5: 2` (float) — consistent with the `.pb.dart` field type `OF`.
- The stubs match what `gen_proto.sh` would produce; field ordering and `_fieldSet` indices are coherent.

### Send path (Task 3)
`record()` now passes `individualPeakFrequency: data.individualPeakFrequency`. `NfbCalibrationData` exposes the field as a non-nullable `double` (`lib/Bci/Models/NfbCalibrationData.dart:23`), so the named arg type-checks. No other field was dropped or reordered.

### Read-back sentinel (Task 4)
```dart
individualPeakFrequency: r.individualPeakFrequency > 0
    ? r.individualPeakFrequency
    : r.individualFrequency,
```
Correct on both legacy paths:
- The server maps `null → 0` (`grpc-mappers.ts` `?? 0`), and proto3 float defaults to `0` on the wire for absent values — both yield `0`, which the `> 0` guard routes to the `individualFrequency` fallback.
- A real calibration peak frequency is always a positive Hz value, so it can never be falsely treated as legacy. The TODO was removed as planned.

### Out-of-scope respected
`NfbCalibrationData.fromJson` keeps its `individualPeakFrequency ?? individualFrequency` local-cache fallback (`:67`) untouched — backward-compatible, no change needed. `importCalibration` and all other fields untouched.

### Build sanity
`flutter analyze lib/Bci/NfbCalibrationGrpcApi.dart` → **No issues found.** The generated files retain the existing brace-less `if` codegen style, which is pre-existing across the whole file and not introduced by this change.

## Runtime risk assessment
- No migration involved (mobile client only; server already shipped `9a294ab`).
- No type mismatches — all fields are `double`/non-nullable.
- No race conditions — pure synchronous DTO mapping.
- Wire compatibility: adding a higher-tag optional float is forward/backward compatible; old servers ignore tag 12 on request, old records decode tag 14 as 0 and fall back gracefully.

## Findings
None.

REVIEW_PASS
