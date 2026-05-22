# Plan Review: BciPairing post-review fixes

**Plan File:** `.ai-factory/plans/47-bcipairing-post-review-fixes.md`
**Risk Level:** 🟢 Low

## Scope verification

Cross-checked each task against the actual source files:

### Task 1 — `IBciPairingService.dart`
Verified docstrings exist exactly where the plan claims:
- Class-level docstring on lines 13–17 (above `abstract class IBciPairingService`).
- Method docstring on lines 19–22 (above `observeChanges()`).
- One-line `///` docstrings on lines 25, 28, 31, 34 (above `startScan`, `connectDevice`, `startCalibration`, `disconnect`).

That accounts for every `///` line in the file. The anchor wording ("above `<member>`") is unambiguous and stable against line drift.

### Task 2 — `BciCalibrationProgressDTO.dart`
Verified: the file contains exactly one docstring block (lines 1–9) above the class. The plan correctly states this is the only docstring in the file. No risk of orphaning fields.

### Task 3 — `BciPairingViewModel.dart`
Both edits verified against current source:
1. Line 27 currently reads `ref.onDispose(() => _eventsSubscription?.cancel());` — exact match for the `old_string` the plan implies. The proposed block form is well-formed Dart.
2. Line 31 holds the `/// Called once by the module assembler...` docstring above `void initState()` — exists as described.

## Correctness analysis

### Field-nulling rationale
The plan's reasoning is sound and the clarifying note in Task 3 is well-placed:
- The `_eventsSubscription != null` guard on line 33 short-circuits re-entry into `initState()`.
- After `ref.onDispose` fires, the subscription is cancelled but the field still holds a (dead) reference, so a second `initState()` call on the same instance would treat the dead subscription as live and skip resubscribing.
- Nulling the field after cancel restores the guard's intended semantics.
- The plan correctly preempts the Riverpod-rebuild misconception: a disposed `Notifier` is replaced with a fresh instance, so the only way the guard matters is repeated `initState()` on the *same* instance (test harness or future assembler change). Calling this out in the plan itself reduces the chance a reviewer or implementer pushes back on the fix.

### No-docs alignment
Removing the `///` blocks aligns with the project's documentation style (CLAUDE.md: docs describe behavior in `docs/`, not via in-code docstrings; the rest of the BciPairing package files have no `///` comments either). Confirmed by spot-checking neighbouring files in the same package — none carry docstrings, so this brings the touched files into consistency.

## Architecture / boundaries
No boundary concerns:
- All edits stay inside `packages/bci_module/lib/src/BciPairing/`.
- No public API change — only inline comment removal and a closure-body expansion that preserves the same `ref.onDispose` contract.
- No proto, no migration, no DTO shape change, no DI wiring change.

## Risk assessment

| Concern | Status |
|---|---|
| Wrong file paths | None — all three paths verified |
| Missing tasks | None — review feedback was limited to these two items |
| API misuse | None — `ref.onDispose` accepts `void Function()`, block form is fine |
| Hidden behavioural change | None — cancelling a cancelled `StreamSubscription` is a no-op; nulling only affects the guard |
| Tests to update | None — Settings: Testing=no; no existing tests reference these docstrings |
| Migration / codegen needed | None |

## Positive notes
- Plan explicitly disambiguates the Riverpod lifecycle concern in the rationale, which preempts a likely reviewer pushback.
- Anchors are member-name based, not line-number based — safe against drift.
- Scope is tight: only the two flagged issues, no scope creep.

## Critical Issues
None.

## Suggestions
None — the plan is ready to implement as written.

PLAN_REVIEW_PASS
