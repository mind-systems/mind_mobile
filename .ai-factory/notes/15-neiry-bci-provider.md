# NeiryBciProvider — Implementation Spec

**Date:** 2026-05-21
**Used by:** ROADMAP Phase 17, milestone 2

## Role

`lib/Bci/NeiryBciProvider.dart` is the **only** file in `mind_mobile` that imports `neiry_kit`. It adapts the raw SDK API to `IBciDeviceProvider`. Everything else in the BCI domain depends on the interface, not this class.

## Dependencies

- `neiry_kit` (path dep `../neiry_kit`)
- `IBciDeviceProvider` + all `lib/Bci/Models/` types (milestone 1)

## Fields

```dart
final DeviceLocator _locator = DeviceLocator();
Device? _device;

final _connectionStateController = StreamController<BciConnectionState>.broadcast();
final _signalQualityController = StreamController<List<BciChannelQuality>>.broadcast();
final _batteryController = StreamController<int>.broadcast();
final _calibrationController = StreamController<BciCalibrationEvent>.broadcast();

StreamSubscription? _connectionSub, _resistanceSub, _batterySub;
```

## scan()

```dart
Stream<List<BciDeviceInfo>> scan() =>
    _locator.requestDevices(type: NeiryDeviceType.headband, searchTime: 5)
        .map((list) => list.map((d) => BciDeviceInfo(serial: d.serial, name: d.name)).toList());
```

`requestDevices` emits **one** `List<DeviceInfo>` after `searchTime` seconds, then the stream closes. Callers re-subscribe to scan again.

## connect(String serial)

```dart
Future<void> connect(String serial) async {
  _device = await _locator.createDevice(serial);
  await _device!.connect();
  await _device!.start();      // activates eegStream, resistanceStream, etc.
  _subscribeDeviceStreams();
}
```

### _subscribeDeviceStreams()

```dart
void _subscribeDeviceStreams() {
  _connectionSub = _device!.connectionStateStream.listen(
    (s) => _connectionStateController.add(_mapConnectionState(s)),
    onError: (e) => Logger.error('NeiryBciProvider: connectionStateStream error: $e'),
  );
  _resistanceSub = _device!.resistanceStream.listen(
    (r) => _signalQualityController.add(_mapResistance(r)),
    onError: (e) => Logger.error('NeiryBciProvider: resistanceStream error: $e'),
  );
  _batterySub = _device!.batteryStream.listen(
    (b) => _batteryController.add(b),
    onError: (e) => Logger.error('NeiryBciProvider: batteryStream error: $e'),
  );
}
```

## disconnect()

```dart
Future<void> disconnect() async {
  await _cancelSubscriptions();
  await _device?.disconnect();
  await _device?.dispose();
  _device = null;
  _connectionStateController.add(BciConnectionState.disconnected);
}
```

## NeiryConnectionState → BciConnectionState

`NeiryConnectionState` has only three values: `disconnected`, `connected`, `unsupportedConnection`. The provider maps only the physical layer:

| NeiryConnectionState | BciConnectionState emitted |
|---|---|
| `connected` | `connecting` (temporary — manager transitions to `impedance` once it receives this) |
| `disconnected` | `disconnected` |
| `unsupportedConnection` | `disconnected` (log error) |

The provider does **not** emit `impedance`, `calibrating`, or `ready` — those transitions are owned by `BciDeviceManager`.

## ResistanceData → List\<BciChannelQuality\>

`ResistanceData` carries per-channel resistance readings. Inspect the actual fields at implementation time (check `neiry_kit/lib/src/models/resistance_data.dart`). Expected structure: list of `(channelName: String, resistance: double)` pairs.

Thresholds for `BciSignalLevel`:
- `good` (green): resistance ≤ 50 kΩ
- `fair` (yellow): 50 kΩ < resistance ≤ 200 kΩ  
- `poor` (red): resistance > 200 kΩ (or null / unavailable)

Adjust thresholds after testing with real hardware if needed.

## startCalibration()

`NfbCalibrator` is a **static** API — not scoped to a `Device` instance. Subscribe in `startCalibration()`:

```dart
Future<void> startCalibration() async {
  NfbCalibrator.calibrateIndividual().listen(
    (event) {
      switch (event) {
        case CalibrationStageFinished(:final stage):
          _calibrationController.add(BciCalibrationStageFinished(stage: stage.index + 1));
        case CalibrationCompleted():
          _calibrationController.add(BciCalibrationCompleted());
      }
    },
    onError: (e) {
      Logger.error('NeiryBciProvider: calibration error: $e');
      _calibrationController.add(BciCalibrationFailed(reason: e.toString()));
    },
  );
}
```

`CalibrationStage` is an enum with 4 values (stage1–stage4). Map to int 1–4 for the DTO.

## dispose()

Cancel all subscriptions, disconnect the device, close all stream controllers.

## What NOT to do

- Do not import this class from outside `lib/Bci/`. All consumers use `IBciDeviceProvider`.
- Do not emit `impedance`, `calibrating`, or `ready` states — those belong to `BciDeviceManager`.
- Do not store or forward `IndividualNfbData` — it is a `neiry_kit` type and must not cross the adapter boundary. `BciCalibrationCompleted` carries no payload in Phase 17.
