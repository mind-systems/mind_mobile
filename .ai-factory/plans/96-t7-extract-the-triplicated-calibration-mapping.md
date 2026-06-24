# Plan: T7 · Extract the triplicated calibration mapping

## Context
The 11-field `NfbCalibrationData ↔ neiry.IndividualNfbData` mapping is duplicated in three places inside `NeiryBciProvider` (forward in `startCalibration` / `startQuickCalibration`, inverted in `importCalibration`). Extract it into one neiry-quarantined mapper so a missed/mis-ordered field can no longer silently truncate a calibration record, and guard completeness with a round-trip test.

## Settings
- Testing: yes (milestone explicitly requires a round-trip test guarding all 11 fields)
- Logging: minimal
- Docs: no

## Key Findings (from recon)
- **T1 is already complete** (`ROADMAP.md:307` is `[x]`) — all three calibration methods already run inside `_queue.enqueue` with a `_disposed` guard. The "depends on T1 / land together" note is satisfied; T7 can land standalone now.
- **Quarantine rule is the deciding constraint.** `NfbCalibrationData` (`lib/Bci/Models/NfbCalibrationData.dart`) is documented as a *pure-Dart domain projection, independent of `neiry_kit`*. Only `NeiryBciProvider` and the port adapters (`NeiryLocatorAdapter`, `NeiryDeviceAdapter`, `NeiryClassifierSet`) may import `neiry_kit`. Therefore **do NOT add `fromNeiry`/`.toNeiry` directly onto the `NfbCalibrationData` model** — that would force the domain model to import `neiry_kit` and break the quarantine. Put the mapper in a dedicated neiry-permitted file under `lib/Bci/Ports/`, alongside the other neiry adapters.
- Mapping details to preserve exactly (behavior-preserving):
  - Forward (`fromNeiry`): `calibratedAt: data.timestamp ?? DateTime.now()` (keep the `?? DateTime.now()` fallback — it only fires when the neiry timestamp is null), `isValid: data.isValid`, `failReason: data.failReason.name`, plus the 8 numeric fields (`individualFrequency`, `individualPeakFrequency`, `individualPeakFrequencyPower`, `individualPeakFrequencySuppression`, `individualBandwidth`, `individualNormalizedPower`, `lowerFrequency`, `upperFrequency`).
  - Inverted (`toNeiry`): `timestamp: data.calibratedAt`, `failReason: neiry.NfbCalibrationFailReason.values.firstWhere((e) => e.name == data.failReason)` (no `orElse` — keep the current throw-on-unknown behavior), plus the same 8 numeric fields. Note `neiry.IndividualNfbData` has no settable `isValid` (it derives `isValid` from `failReason`), so `toNeiry` does not pass it — matching current `importCalibration`.
- `neiry.IndividualNfbData` (const ctor, all params optional) and `neiry.NfbCalibrationFailReason` (public enum, 3 values: `none` / `tooManyArtifacts` / `peakFrequencyAtBorder`) are both publicly constructible — the round-trip test can build a fully-populated `IndividualNfbData` directly.

## Tasks

### Phase 1: Extract the mapper

- [x] **Task 1: Create the neiry calibration mapper**
  Files: `lib/Bci/Ports/NeiryCalibrationMapper.dart`
  Add a new file in the `Ports/` directory (the place where neiry-to-domain mapping is allowed to live — same as `NeiryClassifierSet`). Import `package:neiry_kit/neiry_kit.dart' as neiry` and `../Models/NfbCalibrationData.dart`. Expose a single static mapper class `NeiryCalibrationMapper` with two pure functions:
  - `static NfbCalibrationData fromNeiry(neiry.IndividualNfbData data)` — performs the forward mapping exactly as currently inlined in `startCalibration` (`:289-301`), including the `data.timestamp ?? DateTime.now()` fallback for `calibratedAt` and `data.failReason.name` for `failReason`.
  - `static neiry.IndividualNfbData toNeiry(NfbCalibrationData data)` — performs the inverted mapping exactly as currently inlined in `importCalibration` (`:350-363`), including `firstWhere((e) => e.name == data.failReason)` with no `orElse` (preserve throw-on-unknown). Do not set `isValid` (neiry derives it).
  Add a short doc comment stating this is one of the files permitted to import `neiry_kit`, and that it is the single home of `NfbCalibrationData ↔ neiry.IndividualNfbData` mapping. All 11 fields must be carried in each direction.

- [x] **Task 2: Delegate the three call sites to the mapper** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart`
  Replace the three inline maps with calls to the new mapper:
  - `startCalibration` (`:289-301`): replace the inline `NfbCalibrationData(...)` construction with `NeiryCalibrationMapper.fromNeiry(data)`.
  - `startQuickCalibration` (`:323-335`): replace the inline `NfbCalibrationData(...)` construction with `NeiryCalibrationMapper.fromNeiry(data)`.
  - `importCalibration` (`:350-363`): replace the inline `neiry.IndividualNfbData(...)` construction with `NeiryCalibrationMapper.toNeiry(data)`; keep the existing `await neiry.NfbCalibrator.importCalibrationData(neiryData)` call.
  Add the import for `Ports/NeiryCalibrationMapper.dart`. Leave the surrounding `_queue.enqueue` / `_disposed` guard / `_emitCalibration` logic untouched — this is a pure extraction, no behavior change.

### Phase 2: Guard completeness

- [x] **Task 3: Add the round-trip mapper test** (depends on Task 1)
  Files: `test/Bci/neiry_calibration_mapper_test.dart`
  Add a `flutter_test` suite (mirror the style of `test/Bci/nfb_calibration_repository_test.dart`) covering:
  - **Round-trip preserves all 11 fields:** build a fully-populated `neiry.IndividualNfbData` with a non-null `timestamp` and distinct non-default values for every numeric field, run `fromNeiry` then `toNeiry`, and assert each of the 11 fields (timestamp/`calibratedAt`, `failReason`, and all 8 numeric fields) matches the original. Assert in both directions where helpful (`fromNeiry` output field-by-field, then `toNeiry` output field-by-field).
  - **failReason mapping for every enum value:** assert `fromNeiry` produces the correct `.name` string and `toNeiry` resolves it back to the correct enum for `none`, `tooManyArtifacts`, and `peakFrequencyAtBorder`.
  - **null-timestamp fallback:** `fromNeiry` on an `IndividualNfbData` with `timestamp: null` yields a non-null `calibratedAt` (the `DateTime.now()` fallback path).
  - **unknown failReason throws:** `toNeiry` on an `NfbCalibrationData` with a `failReason` string not in the enum throws (preserves current `firstWhere` behavior).

## Verification
- `flutter test test/Bci/` is green (full BCI suite, including the existing B1/B2 characterization tests — no assertion edits expected).
- A single mapper (`NeiryCalibrationMapper`) is the only place `NfbCalibrationData ↔ neiry.IndividualNfbData` fields are mapped; the three provider methods delegate to it.
- `neiry_kit` is not imported by `NfbCalibrationData.dart` (quarantine intact).
