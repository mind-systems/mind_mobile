# Plan: Clear stale battery on disconnect in the pairing reducer

## Context
Clear the stale battery percentage in the BCI pairing header when the device disconnects, matching the behavior already present in `BciDataService`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Fix reducer

- [x] **Task 1: Clear `batteryPercent` on disconnect**
  Files: `lib/BciModule/BciPairingService.dart`
  In `_reduceStateChanged`, the `BciConnectionState.disconnected` branch (lines ~96-105) calls `acc.copyWith(...)` but does not reset `batteryPercent`. Add `batteryPercent: null,` to that `copyWith` call so the stale percentage is cleared. `BciPairingState.copyWith` uses the `_undefined` sentinel, so passing an explicit `null` actually clears the field (unlike `channels`, where `null` is a no-op). For parity, also add `batteryPercent: null,` to the `BciConnectionState.bluetoothPermissionDenied` branch (lines ~116-123). Keep the existing inline comments style consistent with the surrounding branches.
