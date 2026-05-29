# Plan Review: Per-metric running-max normalization in `BciDataViewModel`

**Plan:** `.ai-factory/plans/82-per-metric-running-max-normalization-in-bcidataviewmodel.md`
**Target file:** `packages/bci_module/lib/src/BciData/BciDataViewModel.dart`
**Risk Level:** 🟢 Low

## Summary

The plan is small, well-scoped, and matches the codebase. The intended change — track a running max per metric in the ViewModel and divide raw NFB/Emotions values by their running max before pushing state — is straightforward and only touches a single file. The supporting types (`BciNfbDTO`, `BciEmotionsDTO`, `BciDataState`) line up exactly with what the plan describes: both DTOs are simple immutable holders with five nullable `double` fields each, and `BciDataState` already exposes a `copyWith` that accepts new `nfb` / `emotions` values.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)** — Not blocking. The change stays inside the presentation package (`packages/bci_module`) and respects the module boundary: it operates on DTOs only, never on domain models or services. ViewModel keeps its role as the module-boundary transformer.
- **Rules (`.ai-factory/RULES.md`)** — No project rules file detected. No violations to flag.
- **Roadmap (`.ai-factory/ROADMAP.md`)** — Not blocking. This is a small UX polish; explicit roadmap linkage is not required.

## Findings

### Minor: Claim about transitive imports is incorrect (Task 1 note)

Task 1 says:

> Do not import `Models/BciNfbDTO.dart` / `Models/BciEmotionsDTO.dart` explicitly — they are reachable transitively through `Models/BciDataState.dart`; add direct imports only if the analyzer requires them when constructing the DTOs in Task 2.

Dart imports are **not** transitive. `BciDataState.dart` imports `BciNfbDTO.dart` and `BciEmotionsDTO.dart` with plain `import`, not `export`, and there are no `export` directives anywhere under `packages/bci_module/lib/src/BciData/Models/`. The moment Task 2 calls `BciNfbDTO(...)` / `BciEmotionsDTO(...)` constructors by name, the analyzer will fail unless those types are imported directly.

The escape hatch ("add direct imports only if the analyzer requires them") covers this in practice, but the framing is misleading. Recommend rewriting the note to simply: *"Add `import 'Models/BciNfbDTO.dart';` and `import 'Models/BciEmotionsDTO.dart';` — needed for the DTO constructor calls in Task 2."* Alternatively, the implementer can use `state.copyWith(nfb: ..., emotions: ...)` and construct the new DTOs via the same explicit imports anyway; there is no way to avoid them.

### Minor: Running max never decays — document the tradeoff

`_maxX = math.max(_maxX, raw)` is monotonically non-decreasing for the VM lifetime. A single transient spike (e.g., an SDK glitch sending an outlier value of 50.0 for `alpha`) compresses the bar to ~2% of its range for the entire session, until the user leaves the BCI data screen and Riverpod disposes the notifier. The plan acknowledges "Riverpod disposes the VM when the screen is left, which provides the implicit reset," which is technically correct but worth restating as an explicit tradeoff: outliers permanently compress the bar within a session. No code change required — this is intentional per the plan's framing — but the next iteration could consider an EMA or windowed max if compression becomes noticeable in practice.

### Minor: Logging setting is "minimal" but no logging is planned

Settings declare `Logging: minimal`. Tasks 1–2 add no log statements. For a one-shot transformation with a clear input/output mapping, this is reasonable. No action required — flagging only because the plan's own settings declared minimal logging and zero is the minimum acceptable interpretation.

## Architectural Alignment

- ✅ Change stays within the presentation package; the domain layer / service / server pipeline are untouched, matching the plan's stated intent ("the domain/server pipeline keeps emitting raw values").
- ✅ ViewModel-as-module-boundary pattern is preserved: the transformation happens at the boundary where DTOs are produced for the UI.
- ✅ `BciMetricBar`'s `clamp(0..1)` is intentionally left as a safety net — correct (handles floating-point edge cases when `raw == _maxX` produces `1.0 + ε` or similar).
- ✅ No proto changes, no migrations, no dependency changes, no exports — package surface unchanged.

## Correctness Check

- Null handling: plan correctly specifies "when the raw value is non-null, update the matching `_maxX` field" and "each field is `raw == null ? null : raw / _maxX`". No division-by-zero risk because `_maxX` is initialized to `1.0` and only ratchets upward.
- Per-metric isolation: plan explicitly forbids cross-normalization. Good.
- The 1.0 floor means values in the documented 0..1 range pass through unchanged. Good — preserves SDK contract behavior for well-behaved sources.

## Positive Notes

- Tasks are atomic, scoped to a single file, and ordered correctly (declare fields, then use them).
- The plan correctly identifies that `state.copyWith(...)` and constructing a new `BciDataState(...)` directly are equivalent here, and leaves the choice to the implementer.
- The note about `BciMetricBar`'s clamp staying as a safety net is exactly right — the implementer might otherwise be tempted to remove it.
- Lifetime / reset semantics are explicitly addressed up front, removing a common review question.

## Recommendations

1. Rewrite the import note in Task 1 to be definitive: instruct the implementer to add both `BciNfbDTO` and `BciEmotionsDTO` imports directly, since Dart does not propagate imports transitively.
2. (Optional) Add a one-line code comment near the `_maxX` field declarations noting that they are intentionally never reset and that the implicit reset is VM disposal — useful for future readers who'll wonder about session-long bar compression.

Neither finding blocks implementation. The plan is implementable as-is; the import note will be auto-corrected by the analyzer the moment the implementer compiles.

PLAN_REVIEW_PASS
