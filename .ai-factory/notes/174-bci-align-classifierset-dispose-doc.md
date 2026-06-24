# Align ClassifierSet.dispose doc with impl (T10)

**Date:** 2026-06-24
**Source:** Phase 56, Tier 4 — nit.

## Key Findings

- The `ClassifierSet` interface doc says `dispose()` "May throw if any classifier fails" (`lib/Bci/Ports/ClassifierSet.dart:36`).
- The production implementation `NeiryClassifierSet.dispose()` (`lib/Bci/Ports/NeiryClassifierSet.dart:99-120`) wraps **each** of the four classifier disposes in its own `try/catch` (`logPrint` on failure) and **never throws**. So the interface contract over-promises a throw that the only implementation does not deliver.
- The provider's teardown paths already `try/catch` around `classifierSet?.dispose()` (`NeiryBciProvider.dart:432-436`, `:483-487`), so callers tolerate either contract — but the doc should describe the actual behavior.

## Details

- Fix the `ClassifierSet.dispose()` doc (`:36`) to state that it disposes all four classifiers and **does not throw** (failures are logged per-classifier), matching `NeiryClassifierSet`. Pure documentation change.

## Guards

- Doc-only; no code/behavior change.
- If the contract is instead chosen to *require* "may throw", that would be a behavior decision affecting callers — out of scope here; this task only aligns the doc to the shipped impl.

## Verify

- The interface doc matches `NeiryClassifierSet.dispose()`'s no-throw behavior.

**Done-when:** the `ClassifierSet.dispose()` doc no longer claims it may throw.
