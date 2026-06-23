# Code Review: A1 · LocatorPort + neiry adapter (behavior-preserving)

**Scope reviewed:** `git diff HEAD` / `git status` — the locator/device port seam landed jointly with A2 (as the plan foresaw). Files:
- `lib/Bci/Ports/LocatorPort.dart` (new)
- `lib/Bci/Ports/DevicePort.dart` (new)
- `lib/Bci/Ports/NeiryLocatorAdapter.dart` (new)
- `lib/Bci/Ports/NeiryDeviceAdapter.dart` (new — A2 surface)
- `lib/Bci/NeiryBciProvider.dart` (modified)
- `test/Bci/neiry_bci_provider_locator_port_test.dart` (new)

**Verdict:** 🟢 No blocking issues. Builds clean, tests pass, production wiring unchanged. Two low-severity logging deviations from the "byte-identical" guard worth recording.

## Checks performed
- `flutter test test/Bci/neiry_bci_provider_locator_port_test.dart` → **3/3 pass** (including the real-adapter default-constructor test — the `neiry.DeviceLocator()` MethodChannel construction does not throw under `flutter test`, so the missing `TestWidgetsFlutterBinding.ensureInitialized()` is not a problem here).
- `flutter analyze lib/Bci/ test/Bci/` → **No issues found** (no unused imports; the `dart:math show min` import was correctly relocated from the provider to `NeiryDeviceAdapter`).
- `lib/Core/App.dart:193` still constructs `NeiryBciProvider()` with no args → default factory builds the real `NeiryLocatorAdapter` → production wiring byte-identical. ✅
- No other consumers reference `LocatorPort` / `DevicePort` outside `lib/Bci/Ports/` + the provider. ✅
- Provider no longer references `neiry.NeiryConnectionState` / `neiry.ResistanceData`; mappings moved cleanly into the adapter; no dangling refs to the removed `_onNeiryConnectionState` / `_onResistance`. ✅
- Teardown gate (`_teardownComplete`, drains at `:117`/`:159`/`:594`, `try/finally` recreate at `:538-539`) untouched; ordering preserved. ✅
- Factory injection correct: `_locatorFactory` recreates the locator on `_resetLocatorSession` (`:445`), matching the original `_locator = neiry.DeviceLocator()` recreate semantics. The `neiry.DeviceLocator()` singleton-reset lifecycle is reproduced exactly by the default factory. ✅
- `scan()` mapping relocation is exact: `BciDeviceInfo(serial: d.serial, name: d.name)` moved into the adapter; port yields already-mapped lists. ✅
- `BciLinkStatus` has exactly `{down, up}` → both `switch` statements (adapter + provider `_onConnectionStatus`) are exhaustive. ✅

## Findings

### 1. `unsupportedConnection` is now logged unconditionally, where it was previously guarded (low)
`NeiryDeviceAdapter.connectionStateStream` (`NeiryDeviceAdapter.dart:67-69`) logs `'unsupported connection'` for **every** `unsupportedConnection` event, then maps it to `BciLinkStatus.down`. In the original provider (`_onNeiryConnectionState`) the log fired **only after** the `if (_device == null) return;` idempotency guard — i.e. it was suppressed during the redundant-event "noise" window that follows our own `disconnect()`.

Net effect: during that brief window an extra `'unsupported connection'` log line can now appear. This is **logging-only — no functional change** (the teardown + emit path is still correctly gated by `_onConnectionStatus` (`:271-278`), which preserves the `_device == null` guard provider-side, exactly as the plan-review prescribed). It is, however, a small deviation from the milestone's "byte-identical" wording. Acceptable as a documented simplification (the adapter cannot see `_device`); flagging so it's a conscious choice rather than an accident. Optional fix: drop the log from the adapter and accept that the unsupported-vs-normal distinction is no longer observable post-seam, or thread the distinction through the port.

### 2. Resistance-mismatch log prefix changed (low / cosmetic)
The channel-count-mismatch warning moved into `NeiryDeviceAdapter._mapResistance` and now prefixes `'NeiryDeviceAdapter:'` instead of `'NeiryBciProvider:'` (`NeiryDeviceAdapter.dart:86-90`). Same trigger, same content; only the source tag differs. No action needed.

## Notes (non-findings, for the A3 author)
- `connect()` does `(_device as NeiryDeviceAdapter).rawDevice` (`NeiryBciProvider.dart:171`) to build the four classifiers. This is correct in production (the real locator always returns a `NeiryDeviceAdapter`) and is explicitly marked `TODO(A3)`. Consequence: any test that drives a *completed* `connect()` with a non-Neiry fake `DevicePort` will throw on this cast — which is why the smoke test deliberately never completes a connect (consistent with the plan's "B1 covers paths without a completed connect()"). The `rawDevice` getter re-exposes `neiry.Device` from the adapter; it is a temporary, documented escape hatch to be removed by A3's `ClassifierFactory` port.
- `connectionStateStream` / `resistanceStream` are `late final` `.map(...)` derivations, listened exactly once per adapter instance, and a fresh adapter is created on every reconnect — no re-listen of a cancelled single-subscription stream.

## Conclusion
The seam is correct, behavior-preserving in all functional paths, type-clean, and leaves production untouched. The two findings are low-severity logging deviations, not bugs. Safe to proceed; consider finding 1 if strict log parity matters.
