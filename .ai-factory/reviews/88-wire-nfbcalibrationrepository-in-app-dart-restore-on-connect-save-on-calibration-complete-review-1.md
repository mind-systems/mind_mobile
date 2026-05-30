# Code Review: Wire NfbCalibrationRepository in App.dart + restore on connect + save on calibration complete

**Plan:** `.ai-factory/plans/88-wire-nfbcalibrationrepository-in-app-dart-restore-on-connect-save-on-calibration-complete.md`
**Changed files:**
- `lib/Core/App.dart`
- `lib/Bci/BciDeviceManager.dart`

The implementation faithfully follows the (post-review) plan: local construction in `App.initialize()`, constructor injection into `BciDeviceManager`, restore-after-connect with fault-isolated `try/catch`, short-circuit to `ready` on successful restore, and persistence gated on `data.isValid && _connectedSerial != null`. The diff is small and clean. The findings below are correctness/UX concerns that the diff exposes — none are blocking, but at least #1 and #2 are worth resolving in this PR.

---

## Findings

### 1. Race widened: `disconnect()` during `importCalibration` will be overridden by `_setState(ready/impedance)`

`lib/Bci/BciDeviceManager.dart:182-208`

Inside `connectDevice`, the `try` block now contains **two** awaits before the terminal `_setState`:
```
await _provider.connect(serial);          // (1)
_connectedSerial = serial;
unawaited(_repository.registerDevice(...));
// ...
await _provider.importCalibration(cal);   // (2) — NEW
// ...
_setState(restored ? ready : impedance);
```

If the user calls `disconnect()` while await (2) is in flight:
- `disconnect()` runs `await _provider.disconnect()`, sets `_connectedSerial = null`, then `_setState(disconnected)`.
- When (2) returns, `_setState(restored ? ready : impedance)` fires unconditionally and overrides the just-set `disconnected` state.
- Result: UI shows `ready` (or `impedance`) for a device the SDK has just been told to disconnect from. `_connectedSerial` is null, so future `BciCalibrationCompleted` events won't persist (good), but the visible state is wrong.

A similar race already existed around `_provider.connect(serial)` itself, but this change adds a second await window and makes it materially wider (calibration import is not instantaneous). It also creates a new race: `disconnect()` between (1) and (2) means we then call `importCalibration` on a device the provider has already torn down.

**Suggested mitigation:** Before the terminal `_setState`, guard on `_state == BciConnectionState.connecting` (the state set on entry at line 183). If the user disconnected mid-flight, `_state` will have moved to `disconnected` and we should not flip it back. Same guard would also fix the pre-existing race around (1). Minimal patch:
```dart
if (_state == BciConnectionState.connecting) {
  _setState(restored ? BciConnectionState.ready : BciConnectionState.impedance);
}
```
Optionally also check `_connectedSerial == serial` to defend against a fast disconnect→reconnect-different-device sequence.

### 2. Restoring calibration bypasses the impedance/contact-quality check

`lib/Bci/BciDeviceManager.dart:203` and `lib/BciModule/BciPairingService.dart:133-156`

On successful restore, the manager transitions directly `connecting → ready`, skipping both `impedance` and `calibrating`. `BciPairingService._reduceConnectionState` maps `ready` to `BciPairingStage.ready` directly, so the UI never opens the impedance screen.

The plan flags this as "the difference between the feature working and the feature secretly doing nothing observable" — true, but there's a clinical side-effect not addressed: the impedance stage is also where the user (and the app) verify that electrodes are making good contact *today*. Cached calibration restored on top of a poorly-worn headset will produce garbage NFB data with no opportunity for the user to notice the problem before the session starts.

This is not a code defect introduced by the diff — it's the intended behavior of the plan — but it's worth confirming with product/UX before merge:
- Option A: keep current behavior (trust cached calibration; rely on `signalQualityStream` consumers to surface poor contact). Add a "re-calibrate" affordance from the ready screen.
- Option B: go `connecting → impedance` even on restore, and only short-circuit to `ready` after the user confirms impedance is good (or via an automated quality threshold).

If A is the chosen direction, no code change is needed — but it should be a deliberate decision rather than an implicit one.

### 3. `BciPairingState.calibration` stays `null` after restore — UI may render "never calibrated" on a restored device

`lib/BciModule/BciPairingService.dart:159-178` (reducer for `BciCalibrationEvent`)

`BciPairingState.calibration: BciCalibrationProgressDTO?` is only populated when `BciCalibrationStageFinished` / `BciCalibrationCompleted` events flow through. On the restore path, no such events fire — `importCalibration` is a silent SDK call. Any UI element that reads `state.calibration?.isComplete` (e.g. to show a "calibrated ✓" badge on the ready screen) will see `null` and may render as if calibration never happened.

The reduce-disconnected path at line 102 explicitly clears `calibration: null`. Whether this is a visible regression depends on what the ready-screen widget actually reads — out of scope for this plan to inspect, but worth a follow-up issue/check before this lands.

If the UI needs a "calibration was restored" signal, emitting a synthetic `BciCalibrationCompleted(restoredFromCache)` event from the manager (or adding a separate `BciCalibrationRestored` event to the sealed class) would be the clean way. Either way, the current diff makes "restored" indistinguishable from "live calibration completed for this session" at the manager level, which the consumer can either ignore or care about.

### 4. Calibration-event persistence may race with reconnect-to-a-different-serial

`lib/Bci/BciDeviceManager.dart:78-81`

```dart
case BciCalibrationCompleted(data: final data):
  if (data.isValid && _connectedSerial != null) {
    unawaited(_nfbCalibrationRepository.record(_connectedSerial!, data));
  }
```

If a `BciCalibrationCompleted` event is delivered late (after the user disconnected and reconnected to a different device), `_connectedSerial` will be the new device's serial and the calibration data will be persisted under the wrong key. This is a thin edge case (calibration events normally fire immediately during `calibrateIndividual()` and the stream is per-device), but it's a real correctness gap that didn't exist before because we weren't persisting anything.

**Mitigation (cheap):** capture `_connectedSerial` at the start of `startCalibration()` and thread it through `BciCalibrationCompleted` (would require an event-payload change), or simply ignore events while `_state` is not in `{calibrating, ready}`. The plan explicitly chose not to gate on `_state == calibrating` to allow late events — that decision is fine for "save what we just produced" but it does open this serial-mismatch window. Worth at least an inline comment acknowledging it.

### 5. Minor: `unawaited` on `nfbCalibrationRepository.record(...)` swallows write errors silently

`lib/Bci/BciDeviceManager.dart:80`

`NfbCalibrationRepository.record` returns `Future<void>` and may throw if `SharedPreferences.setString` fails (disk full, encoding error, etc.). The `unawaited(...)` discards both the success path and any exception. Pattern elsewhere in the file uses `.catchError(...)` on unawaited futures to at least log the failure (see line 187–189 for `registerDevice`).

**Suggested:**
```dart
unawaited(_nfbCalibrationRepository.record(_connectedSerial!, data).catchError(
  (Object e) => logPrint('BciDeviceManager: nfbCalibration record failed: $e'),
));
```

### 6. Minor: import-list ordering in `BciDeviceManager.dart`

`lib/Bci/BciDeviceManager.dart:1-18`

`NfbCalibrationRepository.dart` is inserted between `IBciDeviceProvider.dart` and `Models/BciCalibrationEvent.dart`. The existing convention in this file appears to group `Models/` together; placing `NfbCalibrationRepository.dart` after `BciDeviceRepository.dart` and before `IBciDeviceProvider.dart` would put it next to the other repository import. Cosmetic only — `dart format` and any active linter will sort this if it's wrong by project standards.

---

## Positive Notes

- The diff matches the plan exactly. No silent scope creep.
- Fault-isolating `try/catch` around `importCalibration` is correctly placed (inside the outer `try`, so SDK throws don't propagate into the connect-failure branch).
- `_setState(connecting)` is correctly preserved as the initial transition on entry.
- `registerDevice` was correctly moved above the restore so it always runs after a successful connect, matching prior semantics.
- `data.isValid` gate on the calibration listener correctly protects the 20-entry FIFO from invalid-entry eviction.
- `App.dart` change is minimal: one import, one local construction, one named arg into the existing `BciDeviceManager(...)` call. No public `App` field, in line with the `BciDeviceRepository` precedent.

---

## Recommendation

Address finding #1 in this PR (the race guard is a 3-line change and fixes a pre-existing bug too). Findings #2 and #3 should be triaged with product/UX as follow-ups — they affect what the user sees but aren't introduced by the diff in isolation. Findings #4–#6 are minor and can either be addressed here or deferred to a follow-up if time-boxed.
