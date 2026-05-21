# BciDeviceManager — Implementation Spec

**Date:** 2026-05-21
**Used by:** ROADMAP Phase 17, milestone 5

## Role

`lib/Bci/BciDeviceManager.dart` owns the full device lifecycle state machine and auto-connect logic. It is the only consumer of `IBciDeviceProvider` and `BciDeviceRepository`.

## State machine

```
disconnected → scanning → connecting → impedance → calibrating → ready
                                         ↓                       ↓
                                    (unexpected)            (manual disconnect)
                                         ↓
                                    disconnected (→ auto-reconnect if allowed)
```

### Transitions

| From | To | Trigger |
|---|---|---|
| `disconnected` | `scanning` | `startScan()` called |
| `scanning` | `connecting` | known serial discovered (auto) or user taps device |
| `scanning` | `scanning` | scan completes, no known serial found |
| `connecting` | `impedance` | provider emits `NeiryConnectionState.connected` |
| `connecting` | `disconnected` | connect throws / provider emits disconnected |
| `impedance` | `calibrating` | `startCalibration()` called by user |
| `calibrating` | `ready` | provider emits `BciCalibrationCompleted` |
| `calibrating` | `impedance` | provider emits `BciCalibrationFailed` |
| `impedance/calibrating/ready` | `disconnected` | provider emits `NeiryConnectionState.disconnected` unexpectedly |
| any | `disconnected` | `disconnect()` called manually |

## Auto-reconnect logic

```dart
bool _suppressAutoReconnect = false;
```

- **`startScan()`** — always clears `_suppressAutoReconnect = false` (screen opened fresh).
- **`disconnect()`** (manual) — sets `_suppressAutoReconnect = true` before disconnecting.
- **Unexpected disconnect** (provider emits disconnected while state >= `impedance`) — if `_suppressAutoReconnect == false`, attempt reconnect automatically: transition to `scanning`, call `provider.scan()`, auto-connect if last serial is still in range.

## Auto-connect in startScan()

Auto-connect uses only the **local cache** — no network call on scan. `fetchKnownSerials()` is called once at app start (in `App.initialize()`) purely to refresh the cache for future sessions; the result of that call is never used to trigger an immediate connect.

```dart
Future<void> startScan() async {
  _suppressAutoReconnect = false;
  _setState(BciConnectionState.scanning);

  // Synchronous — no await, no network. If cache is empty, no auto-connect happens.
  final cachedSerials = _repository.cachedSerials();

  provider.scan().listen((discovered) async {
    _discoveredDevices = discovered;
    _discoveredDevicesController.add(discovered);

    if (cachedSerials.isEmpty) return;  // no known devices yet — let user pick manually

    // Auto-connect: first discovered device whose serial is in the cache.
    // Cache is ordered by updated_at DESC (most recently used first).
    final autoConnect = discovered.firstWhereOrNull(
      (d) => cachedSerials.contains(d.serial),
    );
    if (autoConnect != null && _state == BciConnectionState.scanning) {
      await connectDevice(autoConnect.serial);
    }
  });
}
```

**In `App.initialize()`** — refresh cache in background, no await, no side effects:
```dart
unawaited(bciRepository.fetchKnownSerials()); // populates cache for next launch
```
```

## connectDevice(String serial)

```dart
Future<void> connectDevice(String serial) async {
  _setState(BciConnectionState.connecting);
  try {
    await provider.connect(serial);
    _connectedSerial = serial;
    // Provider emits NeiryConnectionState.connected → we map to 'connecting' internally,
    // then transition to impedance here (manager owns this transition):
    _setState(BciConnectionState.impedance);
    // Register with server idempotently — safe on every connect:
    unawaited(_repository.registerDevice(serial));
  } catch (e) {
    Logger.error('BciDeviceManager: connect failed: $e');
    _setState(BciConnectionState.disconnected);
  }
}
```

## startCalibration()

```dart
Future<void> startCalibration() async {
  _setState(BciConnectionState.calibrating);
  await provider.startCalibration();
  // CalibrationEvents flow through provider.calibrationStream → forwarded by manager
}
```

Handle `BciCalibrationCompleted` from `provider.calibrationStream`:
```dart
case BciCalibrationCompleted():
  _setState(BciConnectionState.ready);
```

Handle `BciCalibrationFailed`:
```dart
case BciCalibrationFailed():
  _setState(BciConnectionState.impedance);  // let user retry
```

## disconnect() (manual)

```dart
Future<void> disconnect() async {
  _suppressAutoReconnect = true;
  await provider.disconnect();
  _connectedSerial = null;
  _setState(BciConnectionState.disconnected);
}
```

## Unexpected disconnect handler

Subscribe to `provider.connectionStateStream` in constructor:

```dart
provider.connectionStateStream.listen((state) {
  if (state == BciConnectionState.disconnected &&
      _state != BciConnectionState.disconnected &&
      _state != BciConnectionState.scanning) {
    Logger.error('BciDeviceManager: unexpected disconnect');
    _setState(BciConnectionState.disconnected);
    if (!_suppressAutoReconnect && _connectedSerial != null) {
      _attemptReconnect();
    }
  }
});
```

```dart
Future<void> _attemptReconnect() async {
  _setState(BciConnectionState.scanning);
  // Re-scan for the last known serial
  provider.scan().listen((discovered) async {
    final match = discovered.firstWhereOrNull((d) => d.serial == _connectedSerial);
    if (match != null) await connectDevice(match.serial);
  });
}
```

## Public API

```dart
BciConnectionState get state => _state;
String? get connectedSerial => _connectedSerial;
Stream<BciConnectionState> get stateStream;
Stream<List<BciDeviceInfo>> get discoveredDevicesStream;
Stream<List<BciChannelQuality>> get signalQualityStream;  // forwarded from provider
Stream<int> get batteryStream;                            // forwarded from provider
Stream<BciCalibrationEvent> get calibrationStream;        // forwarded from provider
List<BciDeviceInfo> get discoveredDevices => _discoveredDevices;

Future<void> startScan();
Future<void> connectDevice(String serial);
Future<void> startCalibration();
Future<void> disconnect();
List<String> cachedSerials();   // delegates to repository.cachedSerials()
void dispose();
```
