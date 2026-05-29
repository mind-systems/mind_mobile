# Code Review: Per-metric running-max normalization in `BciDataViewModel`

**Plan:** `.ai-factory/plans/82-per-metric-running-max-normalization-in-bcidataviewmodel.md`
**File changed:** `packages/bci_module/lib/src/BciData/BciDataViewModel.dart`
**Risk Level:** 🟢 Low

## Summary

The implementation matches the plan exactly:
- `dart:math` imported as `math` (line 2).
- `BciNfbDTO` and `BciEmotionsDTO` imported directly (lines 7–8) — the plan's "transitive import" note was wrong (Dart imports are not transitive), and the implementer correctly added explicit imports anyway.
- Ten `_max*` `double` fields initialized to `1.0` (lines 25–35).
- `_onServiceEvent` transforms `state.nfb` and `state.emotions` via `_normalizeNfb` / `_normalizeEmotions`, then builds a new `BciDataState` passing through `heartRate`, `channels`, `batteryPercent`, `isConnected` and the normalized DTOs (lines 52–66).
- Each metric is normalized against its own `_maxX`; null inputs propagate as null; `_maxX` is updated only when the raw value is non-null; running max is monotonically non-decreasing across the VM lifetime as intended.
- `BciMetricBar.clamp(0..1)` is untouched (`Views/BciMetricBar.dart:22`) — safety net preserved.

## Correctness

- **No division-by-zero.** `_maxX` is initialized to `1.0` and only ratchets up via `math.max`, so it is always `≥ 1.0`. Division is always safe.
- **Per-metric isolation.** Each branch uses its own `_maxX`; there is no cross-metric contamination.
- **SDK contract no-op.** Values in `[0, 1]` leave `_maxX = 1.0` and pass through unchanged. Values `> 1.0` ratchet the ceiling, and subsequent samples are scaled proportionally — matches the milestone description.
- **No-reset semantics.** `_max*` fields are not reset in `build()`, on disconnect, or on dispose, matching the plan's explicit "no reset on disconnect" requirement. The VM disposes when the user leaves the screen, providing the implicit reset.
- **Negative raw values.** A negative spike (e.g., raw `-0.3`) does not corrupt `_maxX` (`math.max(1.0, -0.3) == 1.0`), and the negative ratio propagates to `BciMetricBar.clamp(0, 1)` which clamps it to `0`. Correct.
- **`BciDataState` field preservation.** All six fields of `BciDataState` (`heartRate`, `emotions`, `nfb`, `batteryPercent`, `channels`, `isConnected`) are explicitly passed; nothing is dropped. If a new required field is added to `BciDataState` later, the constructor call will fail to compile, which is the desired failure mode.

## Issues

### Minor: NaN / Infinity propagation is silent

If a raw band value is `NaN` (unusual but not impossible from a misbehaving SDK), then `math.max(_maxX, NaN)` returns `NaN` in Dart, which poisons `_maxX` permanently for the VM lifetime. Every subsequent value for that metric becomes `NaN`, and `NaN.clamp(0, 1)` returns `NaN`, which would then drive `AnimatedContainer.height = _maxBarHeight * NaN` — a layout-time crash.

Similarly, `+Infinity` poisons `_maxX` to `Infinity`, after which finite raw values produce `0.0` (mathematically defensible but UX-dead) and infinite raw values produce `NaN`.

Neither is observed in practice — the BCI SDK is expected to emit finite values — and the plan does not require defending against this. Flagging only because the SDK contract is already known to be violated for the 0..1 range, which is the very reason this work exists; it would be reasonable to also guard against non-finite inputs. A one-line guard such as `if (raw.delta != null && raw.delta!.isFinite)` would suffice. Not blocking.

### Minor: Outliers permanently compress the bar within a session

`_maxX` is monotonically non-decreasing for the VM lifetime, so a single transient spike (e.g., `alpha == 50.0` due to an SDK glitch) compresses the `alpha` bar to ~2% of its range until the user leaves the screen. The plan-review flagged this as an intentional tradeoff and the implementation honors it — flagging here only so future iterations know where to look if compression becomes noticeable in practice. No code change required.

### Nit: Long lines in `_normalizeEmotions`

Lines 86–89 and 92–96 exceed ~100 characters. Dart's default formatter line length is 80; running `dart format` would wrap them. Cosmetic, non-blocking.

## Architectural Alignment

- ✅ Change is confined to `packages/bci_module/lib/src/BciData/BciDataViewModel.dart` — single-file scope as planned.
- ✅ Domain/service/server pipeline untouched — raw values still flow to the server-bound pipeline; normalization is presentation-only.
- ✅ ViewModel-as-module-boundary pattern preserved; DTOs in / DTOs out.
- ✅ No new exports, no proto changes, no migrations, no dependency changes.

## Verification

- `git status` / `git diff HEAD` reviewed end-to-end.
- `BciDataViewModel.dart` read in full (1–103); `BciMetricBar.dart` read in full to confirm the clamp safety net is intact.
- DTO definitions (`BciNfbDTO`, `BciEmotionsDTO`) and `BciDataState` constructor signature checked — all six fields are accounted for in the new constructor call.
- No tests were planned; none were added; consistent with `Testing: no` in the plan.

REVIEW_PASS
