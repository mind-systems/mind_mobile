# Plan: T10 · Align ClassifierSet.dispose doc with impl

## Context
Fix the `ClassifierSet.dispose()` interface doc so it matches the shipped no-throw behavior of `NeiryClassifierSet.dispose()`, which wraps each classifier dispose in its own try/catch and never throws.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Documentation fix

- [x] **Task 1: Correct the dispose() doc comment**
  Files: `lib/Bci/Ports/ClassifierSet.dart`
  Replace the doc comment on `dispose()` (line 36): `/// Disposes all four classifiers. May throw if any classifier fails.`
  with wording that matches the actual `NeiryClassifierSet.dispose()` behavior — it disposes all four classifiers and does **not** throw; per-classifier failures are caught and logged. Suggested replacement:
  `/// Disposes all four classifiers. Does not throw — each classifier's dispose`
  `/// failure is caught and logged individually so one failure does not skip the rest.`
  Do not change any code or method signatures. This is the only change in the milestone.
