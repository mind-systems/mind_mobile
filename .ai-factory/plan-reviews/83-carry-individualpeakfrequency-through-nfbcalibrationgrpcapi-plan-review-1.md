# Plan Review: Carry `individualPeakFrequency` through `NfbCalibrationGrpcApi`

**Plan:** `83-carry-individualpeakfrequency-through-nfbcalibrationgrpcapi.md`
**Risk Level:** 🟢 Low

## Verification against the codebase

Every claim in the plan was checked against the live code and the server contract:

- **Proto diff (Task 1):** Diffed `mind_api/proto/nfb_calibration.proto` against `mind_mobile/proto/nfb_calibration.proto`. The server file is identical except for exactly the two stated lines — `float individual_peak_frequency = 14;` in `NfbCalibrationRecord` (after `created_at = 13`) and `float individual_peak_frequency = 12;` in `RecordNfbCalibrationRequest`. The "verbatim copy" instruction is correct and the field-tag claims are accurate. No tag collisions.
- **Codegen (Task 2):** `scripts/gen_proto.sh` exists, cleans `lib/Core/Grpc/generated/`, and regenerates from `proto/*.proto`. Existing `nfb_calibration.pb*.dart` stubs are present, so the path and regeneration model are right.
- **Send field (Task 3):** `NfbCalibrationGrpcApi.record()` constructs `RecordNfbCalibrationRequest` with the sibling `individual*` fields; `NfbCalibrationData` (`lib/Bci/Models/NfbCalibrationData.dart:23`) already exposes `individualPeakFrequency`. Adding the named arg is a clean addition.
- **Read-back sentinel (Task 4):** The `// TODO(mind_api Phase 29)` comment and the faked `individualPeakFrequency: r.individualFrequency` assignment are exactly at `_recordToDomain` lines 42–43. The `> 0` sentinel is the logical complement of the TODO's "`<=0` sentinel rule."
- **Server-side assumption confirmed:** `mind_api/src/grpc/grpc-mappers.ts:167` maps `individualPeakFrequency: entity.individualPeakFrequency ?? 0`, the column is nullable (`entities/nfb-calibration-record.entity.ts:38`, migration `1780250925581`), and `nfb-calibration.service.ts:35` persists `req.individualPeakFrequency`. The "server maps null → 0" basis for the sentinel is correct and the round-trip is fully supported server-side. Additionally, proto3 float defaults to 0 on the wire, so legacy records decode to 0 regardless — the sentinel is robust either way.
- **Out-of-scope items are sound:** `NfbCalibrationData.fromJson` (line 67) already falls back `individualPeakFrequency ?? individualFrequency`, so leaving the local cache untouched is correct and backward-compatible.

## Context Gates

- **Architecture (ARCHITECTURE.md present):** WARN-free. The change stays inside the gRPC boundary layer (`lib/Bci/NfbCalibrationGrpcApi.dart`) — DTO/wire mapping only, no domain or UI leakage. Respects the "proto is owned by `mind_api`, copy verbatim, never symlink" rule from both root and mobile CLAUDE.md.
- **Rules (RULES.md present):** No violations. Single-commit, minimal-logging plan; commit message "Carry individualPeakFrequency through NfbCalibrationGrpcApi" follows the no-type-prefix / sentence-case convention.
- **Roadmap (ROADMAP.md present):** Linked. Matches Phase 54 / line 280 milestone verbatim, including commit ref `9a294ab` and spec note `151-mobile-carry-individual-peak-frequency.md`.

## Critical Issues

None.

## Minor Notes

- Line reference "`record()` (L10-22)" is approximate — the method spans L9–26 and the constructor call L10–22; harmless.
- After Task 2, worth a one-line `flutter analyze` sanity check that the regenerated stub indeed exposes `individualPeakFrequency` before editing (already implied by Task 2's "Confirm…" and the Verify section).

## Positive Notes

- Correctly identifies that the domain model and SDK→domain mapping already carry the field, so only the wire needs fixing — no over-scoping.
- The sentinel rule is defensively correct for both legacy (0) and fresh records, and the server-side `?? 0` assumption was confirmed rather than assumed.
- Explicit, accurate out-of-scope list prevents incidental churn to `importCalibration` and the local-cache fallback.

PLAN_REVIEW_PASS
