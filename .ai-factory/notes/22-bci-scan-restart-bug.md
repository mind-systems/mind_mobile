# BCI scan animation missing on second screen open

## Root cause

`BciDeviceManager._setState` guards against same-state transitions: `if (next == _state) return`. This is correct for internal transitions but breaks the explicit `startScan()` call when the screen is reopened.

Sequence on second open:
1. Screen closes → `ProviderScope` disposed → `BciPairingViewModel` cancelled. `BciDeviceManager` is a singleton in `App.shared` — it stays alive in `scanning` state (scan was never stopped, `_scanSub` is still active).
2. Screen opens → new `ProviderScope` → `BciPairingViewModel.initState()` → `service.startScan()` → `BciDeviceManager.startScan()` → `_setState(scanning)` → guard fires (`next == _state`) → **no event emitted**.
3. `BciPairingService.observeChanges()` subscribes to `bciNotifier.stream` (BehaviorSubject). The BehaviorSubject replays its last cached event — which is whatever fired last during the previous scan session (e.g. `BciDevicesDiscovered`). The `.scan()` accumulator processes that seed with `isScanning` coming out `false`.
4. No fresh `BciStateChanged(scanning)` ever arrives → `isScanning` stays `false` in the accumulated state → `LinearProgressIndicator` never shows.

## Fix

In `lib/Bci/BciDeviceManager.dart`, replace the `_setState(BciConnectionState.scanning)` call at the top of `startScan()` with a direct forced emit that bypasses the dedup guard:

```dart
Future<void> startScan() async {
  _suppressAutoReconnect = false;

  // Force-emit scanning state even if already scanning. _setState deduplicates
  // same-state transitions, which silences this event when the pairing screen
  // is reopened (manager stays alive between screen sessions). A new subscriber
  // needs a fresh BciStateChanged(scanning) to show the progress indicator.
  _state = BciConnectionState.scanning;
  if (!_disposed && !_stateController.isClosed) {
    _stateController.add(BciConnectionState.scanning);
  }

  final cachedSerials = _repository.cachedSerials();
  await _scanSub?.cancel();
  _scanSub = _provider.scan().listen( ...  // rest unchanged
```

Only the two lines `_setState(BciConnectionState.scanning)` → direct assign + broadcast change. Everything else in `startScan()` stays the same.

`_setState` itself is not changed — its dedup guard is correct for all internal transitions (unexpected disconnect, calibration state machine). The force-emit is local to the explicit `startScan()` entry point only.
