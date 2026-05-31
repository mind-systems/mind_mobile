# Task Spec — Carry `individualPeakFrequency` through the NFB calibration round-trip

**Date:** 2026-05-31
**Roadmap:** ROADMAP.md Phase 26
**Provenance:** note 44 Q2 (note 38 Area D)

## Current state
The round-trip is lossy: neiry's `IndividualNfbData.individualFrequency` and `.individualPeakFrequency` are two distinct SDK fields (`neiry_kit .../CNFBCalibrator.h:37,41`, read independently on both platform bridges), but `lib/Bci/Models/NfbCalibrationData.dart` stores only `individualFrequency`, and `lib/Bci/NeiryBciProvider.dart:399` restores neiry's peak from that single stored value — corrupting the peak on every reconnect-restore.

## Target
1. Add `final double individualPeakFrequency` to `NfbCalibrationData`:
   - const constructor param;
   - `toJson` key `'individualPeakFrequency'`;
   - `fromJson` with backward-compat default `json['individualPeakFrequency'] ?? json['individualFrequency']` so existing local cache AND server-synced history don't break.
2. Capture it in `startCalibration`'s `CalibrationCompleted` mapping (~`NeiryBciProvider.dart:372`) from `data.individualPeakFrequency`.
3. Restore it in `importCalibration` (~`:399`) from `data.individualPeakFrequency` instead of duplicating `individualFrequency`.

## Guards
- The three changes above (model + two SDK mapping sites) ship atomically. They fix the **local cache + live SDK round-trip** — i.e. restoring calibration on the same device from the local cache on reconnect (the core bug).

## Server sync — BLOCKED on a mind_api proto change
**Verified: `proto/nfb_calibration.proto` has NO `individual_peak_frequency` field** (only `individual_frequency`, plus the unrelated `individual_peak_frequency_power` / `_suppression`), and `mind_api/src` has no such column. So:
- `NfbCalibrationGrpcApi.record()` cannot send the peak, and `_recordToDomain()` cannot read it.
- **Critical:** `NfbCalibrationRepository.refreshFromServer` REPLACES the local cache with server data (server is the source of truth for history). So on the next BCI-screen open, the locally-captured peak is **overwritten with the server's missing/default value** — the local-only fix is silently undone.

Therefore the fix is only durable once mind_api adds the field. **mind_api ACCEPTED this** — tracked as their Phase 29; the confirmed wire contract is in **note 60**. Requirement filed at `mind_api/.ai-factory/notes/22-nfb-calibration-peak-frequency-field.md`.

### Confirmed contract (note 60)
- Proto field: `individual_peak_frequency`, `float`; numbers `NfbCalibrationRecord` → **14**, `RecordNfbCalibrationRequest` → **12** (existing fields not renumbered).
- **`0.0` sentinel:** proto3 `float` defaults to `0.0`, so legacy/unset rows arrive as `0.0` on the wire (NOT null). Peak frequency is always ~8–13 Hz, so **treat `<= 0` as "absent" and fall back to `individualFrequency`** — never treat `0.0` as a real peak.

**After mind_api Phase 29 ships** — copy the updated `proto/nfb_calibration.proto` into `mind_mobile/proto/` and regenerate stubs (do NOT regen before it lands), then:
- `NfbCalibrationGrpcApi.record()` — add `individualPeakFrequency: data.individualPeakFrequency` to `RecordNfbCalibrationRequest`.
- `NfbCalibrationGrpcApi._recordToDomain()` — apply the sentinel rule, NOT a raw read:
  `individualPeakFrequency: r.individualPeakFrequency > 0 ? r.individualPeakFrequency : r.individualFrequency`.
  (This keeps `refreshFromServer` from writing a bogus `0.0` peak into the local cache for legacy rows; it falls back to `individualFrequency`, consistent with the local `fromJson` default.)

## Files
- `lib/Bci/Models/NfbCalibrationData.dart`
- `lib/Bci/NeiryBciProvider.dart`
- `lib/Bci/NfbCalibrationGrpcApi.dart` — **gated on the mind_api proto change + stub regen** (see above).
