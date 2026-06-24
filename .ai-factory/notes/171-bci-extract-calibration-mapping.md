# Extract the triplicated calibration mapping (T7)

**Date:** 2026-06-24
**Source:** Phase 56, Tier 3 — cleanup / altitude debt. Lands well with `[[165-bci-serialize-calibration-through-queue]]`.

## Key Findings

- The 11-field `NfbCalibrationData ↔ neiry.IndividualNfbData` mapping is duplicated in `lib/Bci/NeiryBciProvider.dart`:
  - `startCalibration` (`:285-297`, neiry→domain),
  - `startQuickCalibration` (`:316-328`, neiry→domain),
  - `importCalibration` (`:340-353`, inverted domain→neiry, `:354` calls `importCalibrationData`).
- A missed/mis-ordered field **silently truncates** a calibration record. This is also the **last place** the provider maps neiry types inline rather than behind an adapter/port.

## Details

- Extract the mapping into one place: `NfbCalibrationData.fromNeiry(neiry.IndividualNfbData)` + `.toNeiry()` (or a small `CalibratorPort`/adapter that owns it). The three methods then call the single mapper.
- All 11 fields must be carried: `calibratedAt`/`timestamp`, `isValid`, `failReason` (`.name` ↔ enum lookup), `individualFrequency`, `individualPeakFrequency`, `individualPeakFrequencyPower`, `individualPeakFrequencySuppression`, `individualBandwidth`, `individualNormalizedPower`, `lowerFrequency`, `upperFrequency`.

## Guards

- **Dependency:** best done in the **same change as `[[165-bci-serialize-calibration-through-queue]]`** (T1) — both touch the calibration methods; doing them together avoids a second pass over the same code.
- Behavior-preserving — identical field-by-field mapping; no truncation, no new fields.
- If routed through a `CalibratorPort`, keep `neiry_kit` quarantined and out of non-adapter files.

## Verify

- A single mapper is the only place neiry↔domain calibration fields are mapped; the three methods delegate.
- A round-trip test (`fromNeiry` then `toNeiry`) preserves all 11 fields; calibration flows unchanged. Suites green.

**Done-when:** the calibration mapping exists once, the three call sites delegate, a round-trip test guards completeness.
