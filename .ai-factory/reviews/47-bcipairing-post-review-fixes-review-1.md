# Code Review: 47 — BciPairing post-review fixes

**Reviewed:**
- `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart`
- `packages/bci_module/lib/src/BciPairing/IBciPairingService.dart`
- `packages/bci_module/lib/src/BciPairing/Models/BciCalibrationProgressDTO.dart`

## Diff verification

### `IBciPairingService.dart`
Every `///` line in the file has been removed (class-level block and the five member docstrings on `observeChanges`, `startScan`, `connectDevice`, `startCalibration`, `disconnect`). The interface declarations, sealed event class, and import are intact. No orphaned blank `///` separator lines were left behind. File parses; analyzer clean.

### `BciCalibrationProgressDTO.dart`
The 9-line class docstring is gone; class declaration, fields (`stagesCompleted`, `isComplete`), and const constructor are unchanged.

### `BciPairingViewModel.dart`
- `ref.onDispose` is now a block closure that cancels and nulls `_eventsSubscription`. Matches the plan exactly.
- The `/// Called once by the module assembler...` line above `initState()` is removed.
- `initState()`, `_onServiceEvent`, and the user-gesture methods are untouched.

## Correctness analysis

- `StreamSubscription.cancel()` returns a `Future<void>` and is safe to invoke once; nulling the field afterward does not affect the in-flight cancellation. No race: the cancellation `Future` is discarded, which matches the previous single-expression form (`=> _eventsSubscription?.cancel()`), so the semantic baseline is preserved.
- The closure captures the `BciPairingViewModel` instance through `this`; the field write `_eventsSubscription = null` mutates the same Notifier instance that owns `initState()`'s guard, so the guard genuinely sees `null` on a subsequent `initState()` call on the same instance. The fix achieves its stated purpose.
- `Notifier.build()` runs every time the provider is first read after disposal, and Riverpod disposal destroys the Notifier instance — so the `onDispose` callback's null-write is only observable when `initState()` is called twice on the same live instance (the failure mode the plan describes). Nothing else relies on `_eventsSubscription` being non-null post-dispose. No regression.
- Removing the docstrings has no compilation effect (no `dartdoc`-style references or generated bindings depend on them). `flutter analyze packages/bci_module` reports no issues.

## Behavioural risk

| Concern | Status |
|---|---|
| Compile/analyzer error | None — analyzer clean |
| Race in disposed-instance reuse | None — field write happens synchronously inside the callback |
| Lost semantic info from removed docs | Minor — the `BciCalibrationProgressDTO` doc captured a non-obvious invariant ("`isComplete` may be true while `stagesCompleted < 4`"); intentionally removed per the project's no-docs stance. Not a defect, but worth being aware of if that invariant ever needs to be re-discovered. |
| Hidden coupling to docstrings | None — no `@macro` / `dartdoc` references found |
| Tests broken | None — no tests in scope per plan settings |

## Scope adherence

All edits are confined to the three files named in the plan. No collateral changes to `BciPairingService`, coordinator, screen, or assembler. The post-review milestone is complete as specified.

REVIEW_PASS
