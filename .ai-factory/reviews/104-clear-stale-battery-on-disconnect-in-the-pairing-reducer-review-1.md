# Code Review: Clear stale battery on disconnect in the pairing reducer

**Files reviewed:** `lib/BciModule/BciPairingService.dart`
**Risk Level:** 🟢 Low

## Summary
The change adds `batteryPercent: null` to the `disconnected` and `bluetoothPermissionDenied` branches of `_reduceStateChanged`, clearing a stale battery percentage from the pairing header after the device drops. The diff is two lines and matches the plan exactly.

## Correctness Verification

### Sentinel behavior — correct
`BciPairingState.copyWith` declares `Object? batteryPercent = _undefined` (line 53) and resolves it via `identical(batteryPercent, _undefined) ? this.batteryPercent : batteryPercent as int?` (lines 67-69). Passing an explicit `null` is therefore distinguished from "not passed" and genuinely clears the field. The `as int?` cast is null-safe. Confirmed against `packages/bci_module/lib/src/BciPairing/Models/BciPairingState.dart`.

### Comment accuracy — correct
Both new lines are annotated `// cleared via _undefined sentinel`, which is accurate and consistent with the adjacent `calibration` / `errorMessage` lines. The contrast with `channels` (a plain `List?` where `null` is a no-op) remains correctly documented on line 103.

### Parity with `BciDataService` — correct
`BciDataService` clears `batteryPercent: null` on both its disconnect-class branches; this change brings `BciPairingService` into alignment. The other state branches (`scanning`, `connecting`, `impedance`, `calibrating`, `ready`) intentionally retain `batteryPercent`, which is correct — battery is only stale once the device is gone.

### No regressions
- `BciBatteryUpdated` still repopulates `batteryPercent` via `copyWith(batteryPercent: percent)` (line 79) when the device reconnects, so clearing on disconnect does not strand the field.
- No other branch or caller depends on `batteryPercent` surviving a disconnect.

## Findings
None.

REVIEW_PASS
