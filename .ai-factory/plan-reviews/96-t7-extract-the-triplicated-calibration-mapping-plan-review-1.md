# Plan Review: T7 · Extract the triplicated calibration mapping

**Plan:** `.ai-factory/plans/96-t7-extract-the-triplicated-calibration-mapping.md`
**Risk Level:** 🟢 Low — accurate, behavior-preserving extraction with correct architectural placement.

## Verification Against the Codebase

Every concrete claim in the plan was checked against the live source. All correct:

- **Triplicated mapping confirmed.** `NeiryBciProvider.dart` contains the forward map inline in `startCalibration` (`:289-301`) and `startQuickCalibration` (`:323-335`), and the inverted map in `importCalibration` (`:350-363`). The plan's line numbers match the *current* file exactly (the ROADMAP/spec-note line numbers are stale pre-T1/T6 offsets — the plan correctly re-derived them).
- **T1 is `[x]`** (`ROADMAP.md:307`), and all three methods already run inside `_queue.enqueue` with a `_disposed` guard. The "land with T1" dependency is satisfied; standalone landing is justified.
- **Quarantine reasoning is sound and is the key value-add of this plan.** `NfbCalibrationData.dart` is a pure-Dart projection (`:3-7`) with no `neiry_kit` import; `NeiryBciProvider`'s doc comment (`:33-38`) names the adapters permitted to import `neiry_kit`. Putting `fromNeiry`/`toNeiry` *on the model* (as the ROADMAP's literal "`NfbCalibrationData.fromNeiry`/`.toNeiry`" phrasing suggested) would break the quarantine. The plan's deviation — a dedicated `lib/Bci/Ports/NeiryCalibrationMapper.dart` alongside `NeiryClassifierSet` — is the correct call and is explicitly justified.
- **Mapping details preserved exactly.** `data.timestamp ?? DateTime.now()` fallback, `data.failReason.name`, `firstWhere((e) => e.name == ...)` with no `orElse`, and not setting `isValid` on `toNeiry` all match the current source. `neiry.IndividualNfbData` (`individual_nfb_data.dart`) derives `isValid` from `failReason` (`:57`) and has no settable `isValid` — confirmed; `toNeiry` correctly omits it.
- **Test feasibility confirmed.** `IndividualNfbData` has a const ctor with all-optional params; `NfbCalibrationFailReason` is a public 3-value enum (`none`/`tooManyArtifacts`/`peakFrequencyAtBorder`). Both are exported from `neiry_kit.dart` (`:19`, `:24`), so the test can build a fully-populated instance directly. `firstWhere` with no `orElse` throws `StateError` on an unknown reason — the "unknown failReason throws" case is valid.
- **Paths and conventions correct.** `Ports/` neiry-import precedent exists (`NeiryClassifierSet.dart:1`); the `Neiry*` filename prefix and the `../Models/NfbCalibrationData.dart` relative import are both right. Test path `test/Bci/neiry_calibration_mapper_test.dart` matches the existing snake_case suite naming.

## Context Gates

- **Architecture:** WARN (informational) — no explicit `Ports/`/quarantine rule lives in `ARCHITECTURE.md` or `RULES.md`; the constraint is documented in source doc-comments and `docs/bci/device-provider-boundary.md`. The plan honors it correctly regardless. No action needed.
- **Rules:** PASS — no rule violations; logging is "minimal" per settings and the extraction adds none.
- **Roadmap:** PASS — maps to `ROADMAP.md:313` (T7), satisfies "one mapper; round-trip test guards all 11 fields; suites green."

## Findings

### Critical Issues
None.

### Non-Blocking Suggestion

- **Make the `isValid` assertion explicit in Task 3.** The milestone says "guards all **11** fields," but the round-trip assertion list in Task 3 enumerates only 10 (`timestamp`/`calibratedAt`, `failReason`, + 8 numeric). The 11th field, `isValid`, is special: `toNeiry` intentionally does *not* carry it (neiry derives it from `failReason`), so it cannot be asserted on the neiry side of a round-trip. The plan's "assert `fromNeiry` output field-by-field" clause *does* cover it implicitly, but to truly guard the field against divergence the test should explicitly assert (a) `fromNeiry(...).isValid == data.isValid`, and (b) for a failing `failReason`, the `toNeiry(...)` output's derived `isValid` is `false`. This is the one field whose mapping is asymmetric, so it's the one most worth pinning. Recommend adding it to the enumeration in Task 3 rather than leaving it to the implementer's reading of "field-by-field."

### Positive Notes

- Correctly overrides the ROADMAP's literal "method on the model" suggestion in favor of a quarantine-respecting `Ports/` mapper — the single most important design decision here, and the plan gets it right with explicit reasoning.
- Line numbers were re-derived against the current file rather than copied from the stale spec note.
- Behavior-preservation is called out precisely (the `?? DateTime.now()` fallback, throw-on-unknown `firstWhere`, omitted `isValid`), leaving no room for the implementer to "tidy up" and change semantics.
- Test coverage is well-scoped: round-trip, per-enum failReason, null-timestamp fallback, and unknown-reason throw — these are exactly the divergence points.

PLAN_REVIEW_PASS
