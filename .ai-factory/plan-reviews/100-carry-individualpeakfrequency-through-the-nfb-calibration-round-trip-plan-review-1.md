# Plan Review: Carry `individualPeakFrequency` through the NFB calibration round-trip

**Plan:** `100-carry-individualpeakfrequency-through-the-nfb-calibration-round-trip.md`
**Files Reviewed:** 6 (plan + 5 codebase/context files)
**Risk Level:** 🟢 Low

## Verification Summary

Every concrete claim in the plan was checked against the actual codebase. All file paths, line numbers, API shapes, and field numbers are correct.

| Plan claim | Verified |
|---|---|
| `NfbCalibrationData` has no `individualPeakFrequency` field yet (distinct from the existing `individualPeakFrequencyPower` / `...Suppression`) | ✅ Confirmed (`lib/Bci/Models/NfbCalibrationData.dart`) |
| `CalibrationCompleted` mapping at NeiryBciProvider ~line 376 | ✅ Exactly line 376 |
| `importCalibration` at ~line 407 currently sets `individualPeakFrequency: data.individualFrequency` (the bug) | ✅ Exactly line 407 |
| SDK `IndividualNfbData` exposes a distinct `individualPeakFrequency` field, readable as `data.individualPeakFrequency` | ✅ Confirmed (`neiry_kit/lib/src/models/individual_nfb_data.dart:36`, and `CalibrationCompleted.data` is `IndividualNfbData`) |
| `NfbCalibrationGrpcApi._recordToDomain` constructs from generated stubs lacking a peak field; `record()` request also lacks it | ✅ Confirmed |
| Proto field number **14** is the next free slot on `NfbCalibrationRecord` (existing run 1–13, `createdAt`=13) | ✅ Confirmed in generated `nfb_calibration.pb.dart` |
| Proto field number **12** is the next free slot on `RecordNfbCalibrationRequest` (existing run 1–11, `upperFrequency`=11) | ✅ Confirmed |
| `<= 0`-means-absent sentinel + `0.0` legacy default contract | ✅ Matches note 60 exactly |

## Context Gates

- **Architecture (WARN → none):** The change stays entirely within the domain/provider/repository layers (`lib/Bci/`). No module-boundary, DTO, or ViewModel surface is touched. `NfbCalibrationData` is a pure-Dart domain projection and adding a field does not leak `neiry_kit` types. No boundary violation. ✅
- **Rules (none):** No Module Service, App.dart, or DI changes involved. The three project rules do not apply to this change set. ✅
- **Roadmap (PASS):** Milestone is present and unchecked at `ROADMAP.md:249`, and the plan matches its description (add field + backward-compat `fromJson`, capture/restore separately, gated server sync via mind_api Phase 29 / note 60). Linkage is explicit. ✅

## Critical Issues

None. The plan is implementable as written.

## Observations (non-blocking)

1. **The SDK's "legacy alias" doc comment is misleading — and the plan is right to ignore it.** `neiry_kit/lib/src/models/individual_nfb_data.dart:35` documents `individualPeakFrequency` as a *"Legacy alias for individualFrequency."* Taken at face value this would suggest the whole milestone is a no-op. However, note 60 (from the mind_api/proto owner) explicitly resolves this: the two are **distinct** members in the native `CNFBCalibrator.h` struct (`:37` and `:41`), `fromMap` reads them independently, and the Dart comment is simply wrong. The plan's premise holds. The implementer should *not* be deterred by that comment if they read the SDK source.

2. **Task 4's placeholder leaves a known, documented gap until Phase 2 ships.** Setting `individualPeakFrequency: r.individualFrequency` in `_recordToDomain` means `refreshFromServer` (which does a full cache *replace*) will still flatten any locally-captured distinct peak back to `individualFrequency` for server-sourced rows on the next BCI-screen open. This is not a defect — note 60 explicitly states the local-only fix "is lost on the next `refreshFromServer`; full durability arrives with Phase 29." The plan correctly scopes durability to the gated Phase 2. Worth keeping the TODO comment (Task 4 already mandates it) so this is discoverable.

3. **`fromJson` backward-compat fallback is safe against the null path.** `((json['individualPeakFrequency'] ?? json['individualFrequency']) as num)` cannot hit `null as num` for any real cache entry: `individualFrequency` has always been a required, always-serialized field, so the fallback key is guaranteed present in legacy data. ✅

4. **Constructor blast radius is fully covered.** Only three files construct `NfbCalibrationData` (the model itself, `NeiryBciProvider`, `NfbCalibrationGrpcApi`) — all three are touched by Tasks 1–4. No test fixtures or other call sites would break from the new required parameter. Consistent with Settings → Testing: no.

5. **Type note (informational):** the generated stubs declare these fields as proto `float` (`$_setFloat`) but expose them as Dart `double`, so `r.individualPeakFrequency` and `data.individualPeakFrequency` are both `double` — no conversion friction in Tasks 2/3/6.

## Positive Notes

- Phasing is exactly right: Phase 1 ships atomically and keeps the build green without the proto field; Phase 2 is hard-gated on mind_api Phase 29 with an explicit "verify the field exists on the wire before regenerating stubs" guard, honoring the monorepo proto-ownership rule.
- Field numbers (14 / 12) and the `<= 0` sentinel were cross-checked against the authoritative contract (note 60) rather than guessed — and they match the generated stubs.
- The plan correctly preserves `individualFrequency: data.individualFrequency` unchanged in `importCalibration` (Task 3) rather than collapsing both fields.
- Commit plan cleanly separates the atomic local round-trip (commits 1) from the gated gRPC durability (commit 2).

PLAN_REVIEW_PASS
