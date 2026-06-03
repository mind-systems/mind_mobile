# NFB calibration must always be user-initiated

**Date:** 2026-06-04
**Source:** conversation context

## Bug

`BciDeviceManager.connectDevice(serial)` calls `await _provider.importCalibration(cal)` before `await _provider.connect(serial)`. The Neiry SDK treats an `importCalibration()` call as "device is already calibrated" and fires a synthetic `CalibrationCompleted` event (or transitions the internal state machine to `ready` automatically). `BciDeviceManager._subscribeCalibration` catches `BciCalibrationCompleted` and transitions to `BciConnectionState.ready` — bypassing the `impedance` and `calibrating` stages entirely. The pairing screen jumps to `ready` without the user ever going through the calibration flow.

EEG classification accuracy depends on fresh, session-specific baselines. Individual alpha peak frequency shifts with fatigue, time of day, and session context. An imported calibration from a previous session is a starting guess, not a substitute for a real calibration.

## Fix

**Single file change: `lib/Bci/BciDeviceManager.dart`.**

Remove the `importCalibration()` block from `connectDevice()`:

```dart
// REMOVE these lines:
final cal = _nfbCalibrationRepository.latestValid(serial);
if (cal != null) await _provider.importCalibration(cal);
```

The state machine must always pass through `impedance → calibrating → ready` on every connection. `BciCalibrationCompleted` remains the only trigger for the `ready` transition.

**What stays unchanged:**
- `NfbCalibrationRepository.record()` is still called on `BciCalibrationCompleted` — history is still tracked and synced to the server. The historical data is valuable for analytics and for future opt-in "use previous calibration" flows.
- `NfbCalibrationGrpcApi`, `refreshFromServer`, server sync — all unchanged.
- `IBciDeviceProvider.importCalibration()` stays in the interface — the capability may be useful for an explicit user-initiated "restore previous" action in the future.
- `App.dart` — no changes needed; `nfbCalibrationRepository` field stays.

## Files touched

| File | Change |
|------|--------|
| `lib/Bci/BciDeviceManager.dart` | Delete the `latestValid` check + `importCalibration` call in `connectDevice()` |

## Verify

1. Connect a Neiry device that has prior calibration history in the local cache.
2. Observe that the pairing screen does NOT jump to `ready` — it shows `impedance` and the calibration button.
3. Complete calibration manually — device reaches `ready`.
4. Check `NfbCalibrationRepository.history(serial)` — new record appended, old records intact.
5. Repeat connect — same flow again (impedance → calibrate → ready), no auto-skip.

## Update docs

`docs/bci/nfb-calibration.md` — rewrite «Автовосстановление при подключении» section: the local cache exists for history and server sync; calibration is always performed manually at each connection.

`docs/bci/device-manager.md` — remove the sentence about calibration results being "reused on subsequent connections to avoid recalibration".
