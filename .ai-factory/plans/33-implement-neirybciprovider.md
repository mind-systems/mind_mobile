# Plan: Implement `NeiryBciProvider`

## Context
Create `lib/Bci/NeiryBciProvider.dart` — the single adapter that imports `neiry_kit` and implements `IBciDeviceProvider`. This isolates the third-party SDK behind the domain interface defined in milestone 1; nothing else in `lib/` may import `neiry_kit`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Reference inputs

- Full spec: `.ai-factory/notes/15-neiry-bci-provider.md`.
- Interface: `lib/Bci/IBciDeviceProvider.dart` (already defines `scan()`, `connect`, `disconnect`, `connectionStateStream`, `signalQualityStream`, `batteryStream`, `calibrationStream`, `startCalibration`, `dispose`).
- Domain models in `lib/Bci/Models/`: `BciDeviceInfo`, `BciConnectionState`, `BciChannelQuality` + `BciSignalLevel`, `BciCalibrationEvent` (sealed: `BciCalibrationStageFinished(int stage)`, `BciCalibrationCompleted()`, `BciCalibrationFailed(String reason)`).
- `neiry_kit` is already a path dep in `pubspec.yaml`.
- The project has no `Logger` class — the existing logging utility is the top-level function `logPrint(Object?)` in `lib/Logger.dart`. Use `logPrint` wherever the spec mentions `Logger.error`.
- `ResistanceData.values` is already converted to **kΩ** by `ResistanceData.fromMap` (see `neiry_kit/lib/src/models/resistance_data.dart`), so the thresholds in the spec (50 kΩ / 200 kΩ) apply directly to `values[i]` with no extra division.
- `NeiryConnectionState` enum has three variants: `disconnected`, `connected`, `unsupportedConnection`.
- `NfbCalibrator.calibrateIndividual()` is a static API returning `Stream<CalibrationEvent>`; events are `CalibrationStageFinished(stage: CalibrationStage)` and `CalibrationCompleted(data: IndividualNfbData)`. `CalibrationStage` is `stage1..stage4` with `code` 0..3 — the provider must map `stage.index + 1` (or equivalently `stage.code + 1`) to the domain `int stage` field (1..4) and must NOT forward `IndividualNfbData`.

## Tasks

### Phase 1: Implement the adapter

- [x] **Task 1: Create `NeiryBciProvider` skeleton with fields, constructors, and stream getters**
  Files: `lib/Bci/NeiryBciProvider.dart`
  Create the file `lib/Bci/NeiryBciProvider.dart`. Imports:
  - `dart:async`
  - `package:neiry_kit/neiry_kit.dart`
  - `IBciDeviceProvider.dart`
  - `Models/BciCalibrationEvent.dart`
  - `Models/BciChannelQuality.dart`
  - `Models/BciConnectionState.dart`
  - `Models/BciDeviceInfo.dart`
  - `../Logger.dart` (for `logPrint`)

  Declare `class NeiryBciProvider implements IBciDeviceProvider`. Fields (exactly as in the spec):
  ```dart
  final DeviceLocator _locator = DeviceLocator();
  Device? _device;

  final _connectionStateController = StreamController<BciConnectionState>.broadcast();
  final _signalQualityController = StreamController<List<BciChannelQuality>>.broadcast();
  final _batteryController = StreamController<int>.broadcast();
  final _calibrationController = StreamController<BciCalibrationEvent>.broadcast();

  StreamSubscription<NeiryConnectionState>? _connectionSub;
  StreamSubscription<ResistanceData>? _resistanceSub;
  StreamSubscription<int>? _batterySub;
  StreamSubscription<CalibrationEvent>? _calibrationSub;
  ```
  Implement stream getters (`connectionStateStream`, `signalQualityStream`, `batteryStream`, `calibrationStream`) returning the matching controller's `.stream`.

- [x] **Task 2: Implement `scan()`** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart`
  ```dart
  @override
  Stream<List<BciDeviceInfo>> scan() =>
      _locator
          .requestDevices(type: NeiryDeviceType.headband, searchTime: 5)
          .map((list) => list
              .map((d) => BciDeviceInfo(serial: d.serial, name: d.name))
              .toList());
  ```
  `requestDevices` emits a single snapshot and closes — do not buffer or restart it here.

- [x] **Task 3: Implement `connect(serial)` + private `_subscribeDeviceStreams()`** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart`
  ```dart
  @override
  Future<void> connect(String serial) async {
    _device = await _locator.createDevice(serial);
    await _device!.connect();
    await _device!.start();
    _subscribeDeviceStreams();
  }
  ```
  `_subscribeDeviceStreams()` wires:
  - `_device!.connectionStateStream.listen(_onNeiryConnectionState, onError: ...)`
  - `_device!.resistanceStream.listen(_onResistance, onError: ...)`
  - `_device!.batteryStream.listen(_batteryController.add, onError: ...)`

  Each `onError` calls `logPrint('NeiryBciProvider: <streamName> error: $e')` (no rethrow). Store the returned subscriptions into `_connectionSub`, `_resistanceSub`, `_batterySub`.

- [x] **Task 4: Map `NeiryConnectionState` → `BciConnectionState`** (depends on Task 3)
  Files: `lib/Bci/NeiryBciProvider.dart`
  Add the private method `_onNeiryConnectionState(NeiryConnectionState s)`:
  - `connected` → emit `BciConnectionState.connecting` on `_connectionStateController` (the manager will transition to `impedance` itself).
  - `disconnected` → emit `BciConnectionState.disconnected`.
  - `unsupportedConnection` → `logPrint('NeiryBciProvider: unsupported connection')` and emit `BciConnectionState.disconnected`.

  Use an exhaustive `switch` so a future enum addition produces a compile error. Do NOT emit `impedance`, `calibrating`, or `ready` — those are owned by `BciDeviceManager`.

- [x] **Task 5: Map `ResistanceData` → `List<BciChannelQuality>`** (depends on Task 3)
  Files: `lib/Bci/NeiryBciProvider.dart`
  Add the private method `_onResistance(ResistanceData r)`:
  - Iterate `i` from `0` until `r.channelCount`.
  - Pair `r.channelNames[i]` with `r.values[i]` (already in kΩ).
  - Bucket each value into `BciSignalLevel`:
    - `value <= 50` → `green`
    - `value > 50 && value <= 200` → `yellow`
    - `value > 200` or `NaN`/non-finite → `red`
  - Build a `BciChannelQuality(channelName: name, impedanceOhm: value, level: level)` per channel and add the resulting `List<BciChannelQuality>` to `_signalQualityController`.

  Guard against `channelNames.length != values.length` defensively by iterating up to `min(channelNames.length, values.length, channelCount)` and `logPrint(...)` once if they disagree.

- [x] **Task 6: Implement `startCalibration()`** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart`
  ```dart
  @override
  Future<void> startCalibration() async {
    _calibrationSub?.cancel();
    _calibrationSub = NfbCalibrator.calibrateIndividual().listen(
      (event) {
        switch (event) {
          case CalibrationStageFinished(:final stage):
            _calibrationController.add(
              BciCalibrationStageFinished(stage.index + 1),
            );
          case CalibrationCompleted():
            _calibrationController.add(const BciCalibrationCompleted());
        }
      },
      onError: (Object e) {
        logPrint('NeiryBciProvider: calibration error: $e');
        _calibrationController.add(BciCalibrationFailed(e.toString()));
      },
    );
  }
  ```
  Do NOT forward `CalibrationCompleted.data` (`IndividualNfbData`) — `BciCalibrationCompleted` is payload-free by design.

- [x] **Task 7: Implement `disconnect()` + private `_cancelDeviceSubscriptions()`** (depends on Tasks 3, 6)
  Files: `lib/Bci/NeiryBciProvider.dart`
  Add a private `Future<void> _cancelDeviceSubscriptions()` that awaits and nulls `_connectionSub`, `_resistanceSub`, `_batterySub` (leave `_calibrationSub` alone — `disconnect()` does not stop calibration; `dispose()` does).
  ```dart
  @override
  Future<void> disconnect() async {
    await _cancelDeviceSubscriptions();
    await _device?.disconnect();
    await _device?.dispose();
    _device = null;
    _connectionStateController.add(BciConnectionState.disconnected);
  }
  ```

- [x] **Task 8: Implement `dispose()`** (depends on Tasks 6, 7)
  Files: `lib/Bci/NeiryBciProvider.dart`
  Sequence:
  1. Await `_cancelDeviceSubscriptions()`.
  2. Cancel `_calibrationSub` (and null it).
  3. Best-effort `_device?.disconnect()` then `_device?.dispose()` inside a try/catch that swallows + logs via `logPrint`.
  4. `_device = null`.
  5. Close every controller: `_connectionStateController`, `_signalQualityController`, `_batteryController`, `_calibrationController`.

  Method signature is `void dispose()` to match `IBciDeviceProvider.dispose()` — fire-and-forget the `await`s by making the body synchronous: wrap async teardown in an `unawaited(Future(() async { ... }))` block, or change to `Future<void> dispose() async` only if the interface allows; otherwise schedule the awaits internally without changing the interface signature. Verify the interface signature at implementation time — if it returns `void`, do not change it.

### Phase 2: Verify the build

- [x] **Task 9: Run `flutter pub get` and a compile check** (depends on Tasks 1–8)
  Files: (no source changes)
  Run `/usr/local/bin/flutter pub get` and then `/usr/local/bin/flutter analyze lib/Bci/NeiryBciProvider.dart` (or `flutter analyze`) and confirm: no analyzer errors, the new file is the only one importing `package:neiry_kit/...`, and the class fully satisfies `IBciDeviceProvider` (no `@override` warnings about missing members). Do not invoke this provider from anywhere else — wiring into `App.dart` and `BciDeviceManager` happens in later milestones.

## Notes for the implementer

- Do not import `NeiryBciProvider` from anywhere outside `lib/Bci/` — all consumers use `IBciDeviceProvider`.
- Do not emit `BciConnectionState.impedance`, `.calibrating`, or `.ready` from this class.
- Do not let any `neiry_kit` type (`Device`, `DeviceInfo`, `ResistanceData`, `CalibrationStage`, `IndividualNfbData`, `NeiryConnectionState`, …) appear in any public member, method signature, or stream payload of this class.
- Keep methods small — each `_onX` handler stays a single switch/loop block; mapping helpers may be private free-standing methods on the class.
