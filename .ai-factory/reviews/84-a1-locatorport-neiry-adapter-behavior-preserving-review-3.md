# Code Review 3: A1 · LocatorPort + neiry adapter (behavior-preserving)

**Scope reviewed:** `git diff HEAD` / `git status`. Re-review after the review-2 fixes.

**Verdict:** 🟢 All prior findings resolved. The change is now the scoped, behavior-preserving locator/device seam the milestone specifies. Clean.

## Status of prior findings

| Finding | Round | Status |
|---|---|---|
| Unconditional `unsupportedConnection` log in adapter | R1 #1 | ✅ Fixed in R2 (adapter maps `down` without logging; guard stays provider-side) |
| Resistance-mismatch log prefix `NeiryDeviceAdapter:` | R1 #2 | ✅ Cosmetic, accepted |
| Hot-path debug log in `NeiryBciProvider._onRrInterval` | R2 #1 | ✅ **Removed** — `_onRrInterval` (`:310-317`) is now byte-identical to the original |
| Out-of-scope debug logging in `HeartRateTickService` / `SwitchableTickService` | R2 #2 | ✅ **Reverted** — both files no longer appear in `git status`; `git diff HEAD -- lib/BreathModule/` is empty |

## Re-verification (this round)
- `git status` — change set is now exactly the milestone surface: `NeiryBciProvider.dart` (modified) + the four `lib/Bci/Ports/*.dart` files + the smoke test. No BreathModule files. ✅
- `_onRrInterval` confirmed restored to the original (no added logging). ✅
- `flutter analyze lib/Bci/ test/Bci/` → **No issues found**. ✅
- `flutter test test/Bci/neiry_bci_provider_locator_port_test.dart` → **3/3 pass**. ✅
- `lib/Core/App.dart:193` unchanged (`NeiryBciProvider()`), default factory builds the real `NeiryLocatorAdapter` → production wiring byte-identical. ✅

## Correctness summary (carried from R1/R2, still holds)
- Factory injection (`_locatorFactory`) correctly reproduces the locator recreate-on-reset lifecycle (`_resetLocatorSession`).
- `scan()` mapping relocation into the adapter is exact; port yields already-mapped `List<BciDeviceInfo>`, never neiry types.
- Connection-state mapping moved to the adapter with the `_device == null` idempotency guard correctly retained in the provider's `_onConnectionStatus`.
- Teardown gate (`_teardownComplete`, drains, `try/finally` recreate) and ordering untouched.
- `(_device as NeiryDeviceAdapter).rawDevice` is the documented `TODO(A3)` interim for classifier construction — correct in production; the smoke test deliberately avoids completing a `connect()`.
- `late final .map(...)` streams are listened once per adapter instance; fresh adapter per reconnect — no re-listen hazard.

## Conclusion
The LocatorPort/DevicePort seam is correct, type-clean, behavior-preserving, in-scope, and fully verified. Ready to commit.

REVIEW_PASS
