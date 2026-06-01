# Plan Review: Clear stale battery on disconnect in the pairing reducer

**Plan:** `104-clear-stale-battery-on-disconnect-in-the-pairing-reducer.md`
**Risk Level:** 🟢 Low

## Verification Against Codebase

Every claim in the plan was checked against the source files.

### File path — correct
`lib/BciModule/BciPairingService.dart` exists and contains `_reduceStateChanged` with the described `BciConnectionState.disconnected` and `BciConnectionState.bluetoothPermissionDenied` branches.

### Line numbers — accurate
- `disconnected` branch: lines 96–105 (plan said ~96-105) ✓
- `bluetoothPermissionDenied` branch: lines 116–123 (plan said ~116-123) ✓

Neither branch currently resets `batteryPercent`, confirming the bug.

### `copyWith` sentinel behavior — correct
`BciPairingState.copyWith` (`packages/bci_module/lib/src/BciPairing/Models/BciPairingState.dart`) declares `Object? batteryPercent = _undefined`. An explicit `null` is distinguished from "not passed" via `identical(batteryPercent, _undefined)`, so passing `batteryPercent: null` genuinely clears the field. The plan's contrast with `channels` (a plain `List? ` where `null` is a no-op, requiring an explicit empty list) is also accurate — see line 103's existing comment and the `channels: channels ?? this.channels` fallback at line 63.

### Parity with `BciDataService` — correct
`lib/BciModule/BciDataService.dart` (lines 74–83) clears `batteryPercent: null` (plus `heartRate`, `nfb`, `emotions`, and an empty `channels` list) on **both** the `disconnected` and `bluetoothPermissionDenied` branches. The plan's instruction to add `batteryPercent: null` to both branches in `BciPairingService` correctly mirrors this established behavior.

## Critical Issues
None.

## Observations (non-blocking)
- **Settings alignment.** The plan declares `Testing: no` / `Docs: no`. This is reasonable for a one-line reducer fix with no behavioral surface beyond clearing a stale value; no test or doc update is required.
- **Logging.** `Logging: minimal` is appropriate — this is a pure state reduction with no I/O or failure path worth logging.
- **Scope completeness.** The plan correctly scopes the fix to the two terminal/error branches. The other branches (`scanning`, `connecting`, `impedance`, `calibrating`, `ready`) intentionally retain `batteryPercent`, which matches `BciDataService` (where only the disconnect-class branches clear it). No additional branches need touching.

## Positive Notes
- The plan demonstrates precise understanding of the `_undefined` sentinel pattern — the single most error-prone detail in this change — and explicitly calls out why `null` works for `batteryPercent` but not `channels`.
- It correctly identifies the reference implementation (`BciDataService`) and pursues parity rather than inventing new behavior.
- Instruction to keep inline-comment style consistent with surrounding branches preserves the file's existing documentation conventions.

The plan is accurate, complete, and architecturally sound. No changes required.

PLAN_REVIEW_PASS
