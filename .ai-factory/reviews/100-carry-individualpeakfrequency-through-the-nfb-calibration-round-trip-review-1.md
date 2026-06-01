# Code Review: Carry `individualPeakFrequency` through the NFB calibration round-trip

**Scope:** `git diff HEAD` — 3 source files (model + provider + gRPC API) plus plan/artifact files.
**Phase implemented:** Phase 1 only (Tasks 1–4). Phase 2 (Tasks 5–6) correctly left unstarted, gated on mind_api Phase 29.
**Risk Level:** 🟢 Low

## What was changed

1. `lib/Bci/Models/NfbCalibrationData.dart` — new `final double individualPeakFrequency` field; added to constructor, `toJson`, and `fromJson` (with backward-compat fallback).
2. `lib/Bci/NeiryBciProvider.dart` — `startCalibration` mapping now captures `data.individualPeakFrequency`; `importCalibration` now restores from `data.individualPeakFrequency` instead of duplicating `data.individualFrequency` (the core bug fix).
3. `lib/Bci/NfbCalibrationGrpcApi.dart` — `_recordToDomain` sets the new field to `r.individualFrequency` as a documented placeholder, with a TODO for Phase 2.

## Verification

- **SDK fields are genuinely distinct.** `neiry_kit/lib/src/models/individual_nfb_data.dart` declares both `individualFrequency` (`:33`) and `individualPeakFrequency` (`:36`), and `fromMap` (`:71–73`) reads each from a separate native map key. So capturing/restoring the peak independently carries real information — the prior `importCalibration` line was lossy as the spec described. The misleading `:35` "Legacy alias" doc comment does not reflect runtime behavior; the fix is correct to treat them as distinct. ✅
- **Constructor blast radius fully covered.** Only three files construct `NfbCalibrationData` (model, `NeiryBciProvider`, `NfbCalibrationGrpcApi`) — all three supply the new required param. No test fixtures or other call sites exist, so the new `required` parameter introduces no compile breakage. ✅
- **`fromJson` fallback is null-safe.** `((json['individualPeakFrequency'] ?? json['individualFrequency']) as num).toDouble()` cannot reach `null as num`: `individualFrequency` has always been a required, always-serialized key, so the fallback is guaranteed present for any legacy cache entry. New entries written by `toJson` include the explicit key. ✅
- **Round-trip integrity (the bug fix).** `importCalibration` now passes `individualPeakFrequency: data.individualPeakFrequency` while leaving `individualFrequency: data.individualFrequency` intact — the two SDK fields are no longer collapsed. ✅
- **Phase 2 gating honored.** No proto file or generated stub was touched; `record()` was correctly left alone (its request has no peak field yet). The `_recordToDomain` placeholder keeps the build green and behaves consistently with the `fromJson` fallback (server-sourced legacy rows resolve peak → `individualFrequency`). The TODO comment makes the deferred sentinel-rule work discoverable. ✅

## Findings

None. No correctness bugs, no security concerns, no runtime/type/race issues. The change set is internally consistent, null-safe, and matches both the plan and the spec (note 53 / note 60).

## Observations (non-blocking, informational)

- **Known durability gap until Phase 2 (by design).** With the Task 4 placeholder, `NfbCalibrationRepository.refreshFromServer` (a full cache replace) will still flatten a locally-captured distinct peak back to `individualFrequency` for server-sourced rows on the next BCI-screen open. This is the explicitly-scoped limitation from the spec — full durability arrives with mind_api Phase 29. Not a defect.
- **Phase 2 reminder for the implementer:** when stubs are regenerated, apply the `<= 0`-means-absent sentinel (`r.individualPeakFrequency > 0 ? r.individualPeakFrequency : r.individualFrequency`) and remove the TODO — not a raw read — to avoid writing a bogus `0.0` peak into the local cache for legacy rows.

REVIEW_PASS
