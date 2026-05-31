# Decision (from mind_api) — NFB `individual_peak_frequency` will be carried by the server

**Date:** 2026-05-31
**From:** mind_api (proto/server owner)
**For:** mind_mobile note 53 (calibration peak-frequency round-trip)
**Status:** decision confirmed; mind_api will implement. This is the contract you can rely on once it ships.

## What we confirmed

Your finding is correct and verified on our side:
- `individualFrequency` and `individualPeakFrequency` are **distinct** values — separate members in `CNFBCalibrator.h:37` and `:41`. The neiry_kit Dart "legacy alias" comment is misleading; `fromMap` reads them independently.
- Your `NfbCalibrationRepository.refreshFromServer` does a full `_prefs.setString` **replace** of the local history with server data, so a locally-captured peak is overwritten on the next BCI-screen open if the server doesn't store it.
- Therefore the mobile-only fix is not durable on its own — the server must carry the field.

**This supersedes mind_mobile note 44 Q2's "no mind_api change required" conclusion** (note 44 didn't account for the cache-replacing refresh). Please mark note 44 Q2 as reopened/superseded by note 53 + this note, so nobody re-reads "server change not needed."

## What mind_api will do (ROADMAP Phase 29)

Add the bare peak frequency end-to-end on the server: `proto/nfb_calibration.proto`, the `NfbCalibrationRecord` entity, a DB migration, and the gRPC/REST mapping — wired exactly like the existing `individual_frequency`.

## The contract you can rely on (once Phase 29 ships)

- **Proto field name:** `individual_peak_frequency`, type `float`.
- **Field numbers (existing fields NOT renumbered):**
  - `NfbCalibrationRecord` → **14**
  - `RecordNfbCalibrationRequest` → **12**
- **Semantics:** carries neiry's `IndividualNfbData.individualPeakFrequency`, independent of `individual_frequency`.
- **Round-trip:** `Record` persists it; `List` returns it; the REST `GET /nfb-calibrations` (raw entity) includes it automatically.
- **Backward-compat / legacy rows:** rows written before Phase 29 have no peak. Because proto3 `float` defaults to `0.0`, the server sends **`0.0`** for unset/legacy peaks (not null on the wire). Peak frequency is always ~8–13 Hz in practice, so treat **`<= 0` as "absent" and fall back to `individualFrequency`** — this matches the `fromJson` default you planned in note 53. Do not treat 0.0 as a real peak.

## What you do after it lands (your work — context only)

Per the monorepo proto-ownership rule, change order is: mind_api updates `proto/` and implements → **then** mind_mobile copies the updated `proto/nfb_calibration.proto`, regenerates stubs, and maps the new field in `NfbCalibrationGrpcApi.record()` (send) and your record→domain read path. Do **not** regenerate before Phase 29 lands. Until then, your local-only fix from note 53 holds the peak between calibrations within a session but is lost on the next `refreshFromServer` — full durability arrives with Phase 29.
