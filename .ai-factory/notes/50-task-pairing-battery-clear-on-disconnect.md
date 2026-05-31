# Task Spec — Clear stale battery on disconnect in the pairing reducer

**Date:** 2026-05-31
**Roadmap:** ROADMAP.md Phase 26
**Provenance:** note 42 Task 5 (note 39 Area E)

## Current state
`lib/BciModule/BciPairingService._reduceStateChanged`: the `disconnected` branch clears stage/scanning/connecting/btPermDenied/calibration/channels/errorMessage but NOT `batteryPercent`, so the pairing header shows a stale percentage after the device drops. `BciDataService` already clears it on disconnect — the two reducers are inconsistent.

## Target
- Add `batteryPercent: null` to the `disconnected` branch's `copyWith` (`BciPairingState.copyWith` uses the `_undefined` sentinel, so passing `null` actually clears it).
- Optionally mirror into the `bluetoothPermissionDenied` branch for parity.

## Files
- `lib/BciModule/BciPairingService.dart` (one file).
