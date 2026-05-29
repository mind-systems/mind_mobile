# Plan Review: Carry `NfbCalibrationData` through `BciCalibrationCompleted`

**Plan:** `.ai-factory/plans/84-carry-nfbcalibrationdata-through-bcicalibrationcompleted.md`
**Risk Level:** 🟢 Low

## Summary

Three-file atomic change: add a `data: NfbCalibrationData` payload to the `BciCalibrationCompleted` event variant; map `neiry.IndividualNfbData → NfbCalibrationData` inside `NeiryBciProvider.startCalibration`; teach `BciDeviceManager` to destructure (but ignore) the new field. Verified against the current state of all three files and against the `neiry_kit` source of truth.

## Verified Facts

- **`BciCalibrationEvent.dart`** — current shape matches the plan: sealed base, three final variants, `BciCalibrationCompleted` is a payload-free `const` variant on line 22–24. The "Carries no payload" Dartdoc that the plan replaces is at lines 18–21. ✅
- **`NeiryBciProvider.dart`** — the `neiry` alias import is at line 6, the `Models/...` import block runs through line 26, and the `switch (event)` at lines 361–368 currently emits `const BciCalibrationCompleted()`. ✅
- **`BciDeviceManager.dart`** — the calibration listener lives in `_subscribeProviderStreams()` at lines 70–80 (the plan's footnote correcting the milestone description from `_subscribeCalibration` is accurate). The case body to preserve (`if (_state == BciConnectionState.calibrating) _setState(BciConnectionState.ready);`) is at line 75. ✅
- **`BciPairingService.dart`** — the only other consumer matches `case BciCalibrationCompleted():` at line 172; a bare class pattern continues to match an enriched variant unchanged. ✅
- **`neiry_kit` mapping source** (cross-checked in `/Users/max/projects/mind/neiry_kit/lib/src/models/individual_nfb_data.dart`):
  - `IndividualNfbData.timestamp` is `DateTime?` — fallback to `DateTime.now()` is correct.
  - `isValid` getter exists on line 57 (`failReason == NfbCalibrationFailReason.none`).
  - `NfbCalibrationFailReason` (`/lib/src/models/nfb_calibration_fail_reason.dart`) declares exactly `none`, `tooManyArtifacts`, `peakFrequencyAtBorder` — `enum.name` will produce strings that match `NfbCalibrationData.failReason`'s documented allowed values.
  - `neiry.CalibrationCompleted` is `const CalibrationCompleted({required this.data})` (sealed `CalibrationEvent`, line 51 of `calibration_event.dart`) — destructuring `(:final data)` is valid.
  - `individualPeakFrequency` exists in `IndividualNfbData` (line 36, legacy alias) and is intentionally omitted from `NfbCalibrationData` — the plan's exclusion is correct.
- **`NfbCalibrationData`** — its constructor takes named required fields matching every name in the mapping table. No type mismatches. ✅

## Findings

### Minor: Task 3 is internally inconsistent on which pattern to use

Task 3's bullets give two different instructions for the same change:

- First bullet: "Replace `case BciCalibrationCompleted():` with `case BciCalibrationCompleted(:final data):`."
- Third bullet: "simply discard the binding by renaming the local: use `case BciCalibrationCompleted(data: final _):`."

These produce different code. The implementer will likely take the later (more specific) bullet, which is the intended outcome, but the contradiction should be cleaned up — drop the first bullet or rewrite it as "do not bind the field as `:final data`; see below."

### Minor (style, non-blocking): Task 3 is over-engineered relative to `BciPairingService`

The plan's own cross-cutting note correctly observes that `BciPairingService.dart:172` keeps `case BciCalibrationCompleted():` and continues to compile — a bare class pattern matches the variant regardless of new fields. The simplest equivalent change in `BciDeviceManager` is to leave `case BciCalibrationCompleted():` exactly as today; the `case BciCalibrationCompleted(data: final _):` form is functionally identical and only adds a future-grep hint that the variant now carries a payload.

This is a judgment call — the wildcard form does signal "we know the payload exists, wiring lands later," which is the plan's stated intent. Either form works; the inconsistency with `BciPairingService` is worth noting but not a blocker.

### Note: `const` removal in Task 2 is correct

The plan flags that `_calibrationController.add(BciCalibrationCompleted(mapped))` must drop the `const` because `mapped` derives from `DateTime.now()` when `data.timestamp` is null. Even if `data.timestamp` is non-null, `NfbCalibrationData` instances built from runtime fields are not compile-time constants, so the removal is unconditionally required. ✅

### Note: no import needed in `BciDeviceManager`

Task 3's claim that `NfbCalibrationData` does not need importing because the field is matched by wildcard is correct — Dart resolves the field's type through `BciCalibrationCompleted`'s declaration; the wildcard pattern does not reference the type. ✅

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)** — Plan respects the domain/adapter boundary: `neiry_kit` types stay inside `NeiryBciProvider`, only the pure-Dart `NfbCalibrationData` projection crosses into `BciCalibrationEvent`. The class-level Dartdoc reminder is preserved.
- **Rules (`.ai-factory/RULES.md`)** — Not located in the project; no violations to flag.
- **Roadmap (`.ai-factory/ROADMAP.md`)** — Plan aligns with Phase 24's "carry through `BciCalibrationCompleted`" sub-step, which sequences after the already-merged `NfbCalibrationData` domain model and explicitly defers repository wiring. No linkage gap.

## Positive Notes

- Mapping table is exhaustive and matches the SDK field-by-field, including the deliberate omission of `individualPeakFrequency`.
- The plan correctly identifies and pre-empts the only cross-file compile risk (`BciPairingService` exhaustive switch).
- Footnote correcting the milestone description's stale method name (`_subscribeCalibration` → `_subscribeProviderStreams`) avoids a hunt during implementation.
- `data.timestamp ?? DateTime.now()` correctly handles the `-1` sentinel that `IndividualNfbData.fromMap` decodes to `null`.
- The plan respects the "no Flutter or domain leakage" rule: the new field's type is a pure-Dart projection, not the plugin type.

## Verdict

The plan is implementable as written. The two minor issues (inconsistent Task 3 wording, optional simplification) do not change the outcome and can be resolved at implementation time by following the third bullet of Task 3. No missing migrations, no security implications, no architectural mistakes, all file paths and line references verified against the current tree.

PLAN_REVIEW_PASS
