# Code Review (Round 2): Implement `BciDeviceManager`

**Plan:** `.ai-factory/plans/37-implement-bcidevicemanager.md`
**Spec:** `.ai-factory/notes/16-bci-device-manager.md`
**Files reviewed:**
- `lib/Bci/BciDeviceManager.dart` (192 lines, new)
- `pubspec.yaml` (+ `collection: ^1.19.1`)
- `pubspec.lock` (regenerated)

`flutter analyze lib/Bci/BciDeviceManager.dart` → **0 issues**.

## Round 1 findings — verification

| # | Round-1 finding | Status |
|---|---|---|
| 1 | Unexpected-disconnect listener does not exclude `connecting` | ✅ Fixed — guard now includes `_state != BciConnectionState.connecting` (line 44). |
| 2 | Dispose vs. scan-handler race → "add after close" on `_stateController` | ✅ Fixed — `_disposed` flag short-circuits `_setState`; scan handlers also check `_disposed` and `_discoveredDevicesController.isClosed` before emitting; `dispose()` sets the flag *before* cancelling subs / closing controllers. |
| 3 | `startCalibration()` has no state precondition | ✅ Fixed — `if (_state != BciConnectionState.impedance) return;` (line 145). |
| 4 | `disconnect()` does not cancel ongoing scan | ✅ Fixed — `await _scanSub?.cancel(); _scanSub = null;` runs before `_provider.disconnect()` (lines 161–162). |
| 5 | Late scan emissions flicker `_discoveredDevices` | ✅ Fixed — scan handler now cancels `_scanSub` immediately before initiating `connectDevice`, so subsequent scan emissions are dropped at the source (lines 122–124, 184–186). |
| 6 | Sticky `_suppressAutoReconnect` after manual disconnect skips re-scan | Unchanged (intentional per spec). Not addressed — informational only. |

## New findings

### 1. Unawaited `registerDevice` failure is reported as an uncaught async error (LOW)
`connectDevice` (line 137): `unawaited(_repository.registerDevice(serial));`

`BciDeviceRepository.registerDevice` calls `BciDevicesGrpcApi.register`, which has no internal try/catch. A gRPC failure (offline, server 5xx, auth refresh failure) bubbles out as a rejected Future. Because the call is fire-and-forget via `unawaited()`, the rejection is not swallowed — Dart reports it as an uncaught async error in the current zone.

For Flutter apps with `runZonedGuarded` / `FlutterError.onError` installed, this will surface to crash reporting. Spec-compliant (the spec also writes `unawaited(_repository.registerDevice(serial));`), so flagging as **informational**, not blocking. A defensive wrapper would be:

```dart
unawaited(_repository.registerDevice(serial).catchError(
  (Object e) => logPrint('BciDeviceManager: registerDevice failed: $e'),
));
```

### 2. `_attemptReconnect()` has no exit if the device never reappears (LOW / INFORMATIONAL)
If `_provider.scan()` completes (5 s per `NeiryBciProvider`) without surfacing `_connectedSerial`, the manager stays in `scanning` indefinitely — no `onDone` handler, no fallback to `disconnected`. The same is technically true for `startScan()`, but per the spec transition table that is intentional (`scanning` → `scanning` while user can still pick manually). For a *silent* reconnect attempt the user has no UI affordance to recover; the only way out is a manual `disconnect()` or another explicit `startScan()`.

Not strictly a bug — the spec is silent on the "reconnect scan times out" case — but worth a follow-up note for the `BciNotifier` / UI milestone. A defensive option:

```dart
_scanSub = _provider.scan().listen(
  (discovered) async { ... },
  onError: (...) { ... },
  onDone: () {
    if (_state == BciConnectionState.scanning && _connectedSerial != null) {
      _setState(BciConnectionState.disconnected);
    }
  },
);
```

### 3. Calibration event handler does not gate on current state (LOW)
The `_provider.calibrationStream` listener (lines 51–61) is installed at construction and unconditionally transitions to `ready` on `BciCalibrationCompleted` or `impedance` on `BciCalibrationFailed`.

If the user calls `disconnect()` while calibration is mid-flight, the manager transitions to `disconnected`. A late `BciCalibrationCompleted` emission then drives the manager from `disconnected` → `ready` (no precondition check), leaving the UI in `ready` while there is no live device.

Mitigation: gate the calibration handler on `_state == calibrating`:

```dart
case BciCalibrationCompleted():
  if (_state == BciConnectionState.calibrating) _setState(BciConnectionState.ready);
case BciCalibrationFailed(:final reason):
  logPrint('BciDeviceManager: calibration failed: $reason');
  if (_state == BciConnectionState.calibrating) _setState(BciConnectionState.impedance);
```

Not blocking — the manual-disconnect race window is small and the next user action would resync — but easy to harden.

### 4. `_connectedSerial` is not cleared after a failed `connectDevice` from a manual tap (INFORMATIONAL)
On the failure branch of `connectDevice` (line 142), `_connectedSerial` is left untouched. The current code only writes `_connectedSerial = serial` after a successful `_provider.connect(serial)`, so a fresh (never-connected) user always sees `null`. But after a successful connect + unexpected disconnect + failed reconnect, `_connectedSerial` still points at the last good serial — which is desired for `_attemptReconnect`. So this is consistent with the spec; mentioned only because the next milestone's UI may want to inspect the field after a manual-tap failure and could be misled.

## Positive notes

- All five actionable Round-1 findings were addressed and the fixes are correct.
- `_disposed` early-return is enforced on every write path (`_setState`, both scan handlers), and `dispose()` flips the flag before cancelling subs / closing controllers — eliminating the closed-controller hazard cleanly.
- The unexpected-disconnect guard now excludes both `scanning` and `connecting`, preventing the cascade-reconnect described in Round 1 § 1.
- Scan auto-connect now cancels its own subscription before invoking `connectDevice`, which both prevents flicker (Round 1 § 5) and avoids the new-scan-during-old-handler reentrancy risk.
- `startCalibration` precondition (`_state == impedance`) keeps the state machine honest and matches the spec's transition table.
- `disconnect()` order is correct: suppress flag → cancel scan → provider disconnect → clear serial → state. The provider's broadcast event arrives after the synchronous `_setState(disconnected)`, so the connection-state listener's `_state != disconnected` guard short-circuits as expected.