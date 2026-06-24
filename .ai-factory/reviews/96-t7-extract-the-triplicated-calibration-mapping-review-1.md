# Code Review: T7 · Extract the triplicated calibration mapping

**Scope:** `lib/Bci/Ports/NeiryCalibrationMapper.dart` (new), `lib/Bci/NeiryBciProvider.dart` (modified), `test/Bci/neiry_calibration_mapper_test.dart` (new).
**Verdict:** Clean, behavior-preserving extraction. No correctness, security, or runtime defects found.

## What was checked

- **Full read** of the new mapper, the three modified provider call sites, and the new test in surrounding context.
- **Faithfulness of the extraction** — field-by-field comparison of the old inline maps against the new mapper.
- **Quarantine integrity** — that `neiry_kit` did not leak into the domain model.
- **Build + runtime** — `flutter analyze` on the three files (clean), the new test (11/11 pass), and the full `test/Bci/` suite (81/81 pass).

## Findings

### Correctness — behavior preserved exactly
- `fromNeiry` reproduces the old `startCalibration`/`startQuickCalibration` map verbatim: `calibratedAt: data.timestamp ?? DateTime.now()`, `isValid: data.isValid`, `failReason: data.failReason.name`, and all 8 numeric fields in the same order. The two former call sites now delegate (`NeiryBciProvider.dart:291`, `:314`) with no semantic change — the `DateTime.now()` fallback still only fires on a null SDK timestamp.
- `toNeiry` reproduces the old `importCalibration` inverse map verbatim, including `firstWhere((e) => e.name == data.failReason)` with **no** `orElse` (throw-on-unknown preserved) and the deliberate omission of `isValid` (neiry derives it from `failReason`). The call site (`:329-331`) keeps the `await neiry.NfbCalibrator.importCalibrationData(...)` invocation unchanged.
- The surrounding `_queue.enqueue` / `_disposed` guard / `_emitCalibration` / sealed-`switch` structure is untouched. The `switch` on `neiry.CalibrationCompleted(:final data)` still binds `data` and the completed-event emission is equivalent.

### Quarantine — intact
- `NeiryCalibrationMapper.dart` is the only new importer of `neiry_kit`, placed in `lib/Bci/Ports/` alongside the other permitted adapters. A repo grep confirms the mapper is now the **sole** site mapping `IndividualNfbData` ↔ domain fields (`BciCalibrationEvent.dart` matches are doc-comments only). `NfbCalibrationData.dart` still has no `neiry_kit` import.
- The provider still imports `Models/NfbCalibrationData.dart` and uses it in `importCalibration`'s signature, so no import became dead.

### Tests — adequate and green
- Covers the four divergence points the plan named: full-field round-trip (both directions + composed `fromNeiry→toNeiry`), per-enum `failReason` mapping for all three values, null-timestamp fallback (bounded ±1s window — not flaky), and unknown-`failReason` `throwsStateError`.
- `flutter analyze`: *No issues found.* New test: *+11 All tests passed.* Full `test/Bci/`: *+81 All tests passed* — the existing B1/B2 characterization suites stayed green with no assertion edits.

## Non-blocking observations (no action required)

- **`isValid` coverage is asymmetric but acceptable.** `isValid` is asserted on the `none` path (`expect(domain.isValid, sdk.isValid)`), but the invalid path (`tooManyArtifacts`/`peakFrequencyAtBorder`) asserts only `failReason`, not the derived `isValid`. Since `isValid` is a pure derivation of `failReason` in both types, this is a cosmetic gap, not a correctness risk. The plan-review raised the same point; the current coverage is sufficient for the milestone's "guards all 11 fields" bar.
- **Dartdoc references to `[NeiryLocatorAdapter]` / `[NeiryDeviceAdapter]` / `[NeiryClassifierSet]`** in the mapper's doc comment point to unimported symbols. The analyzer reported no issues, so these resolve or are ignored under the project's lint config — left as-is, matching the documentary style of the neighboring `NeiryClassifierSet` comment.

REVIEW_PASS
