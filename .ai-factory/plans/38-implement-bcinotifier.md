# Plan: Implement `BciNotifier`

## Context
Add the domain-layer notifier that wraps `BciDeviceManager`, exposing a single typed event stream (`BciNotifierEvent`) for the upcoming `bci_module` presentation layer to subscribe to, and wire it into `App.initialize()` so the manager and its dependencies have a lifetime tied to the app.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Domain types and notifier

- [x] **Task 1: Create `BciNotifierEvent` sealed class**
  Files: `lib/Bci/Models/BciNotifierEvent.dart`
  Pure Dart, no Flutter/Riverpod imports. Define a sealed base class `BciNotifierEvent` with `const` constructor, mirroring the style of `lib/Bci/Models/BciCalibrationEvent.dart` (use `final class` for each variant, doc comments). Variants:
  - `BciStateChanged(BciConnectionState state)` — emitted on every connection-state transition from `BciDeviceManager.stateStream`.
  - `BciDevicesDiscovered(List<BciDeviceInfo> devices)` — emitted on every scan snapshot from `BciDeviceManager.discoveredDevicesStream`.
  - `BciSignalQualityUpdated(List<BciChannelQuality> channels)` — emitted on `BciDeviceManager.signalQualityStream`.
  - `BciCalibrationEventReceived(BciCalibrationEvent event)` — wraps each event from `BciDeviceManager.calibrationStream`.
  - `BciBatteryUpdated(int percent)` — emitted on `BciDeviceManager.batteryStream`.
  - `BciError(String message)` — emitted when any underlying provider stream surfaces an error.
  Import the existing domain types from `lib/Bci/Models/` (`BciConnectionState`, `BciDeviceInfo`, `BciChannelQuality`, `BciCalibrationEvent`). Do not import any `neiry_kit` types.

- [x] **Task 2: Implement `BciNotifier`** (depends on Task 1)
  Files: `lib/Bci/BciNotifier.dart`
  Pure Dart, no Flutter or Riverpod imports. Use `rxdart` (`BehaviorSubject`) — follow the shape of `lib/McpModule/Core/TokenNotifier.dart`, but here the subject carries `BciNotifierEvent` (no aggregate state class — the manager owns the canonical state).

  Constructor: `BciNotifier({required BciDeviceManager manager})`. Holds the manager via a private final field. In the constructor body, subscribe to each manager stream and translate each emission into the matching `BciNotifierEvent` variant via `_subject.add(...)`. Use `onError` on each subscription to emit `BciError(e.toString())` and `logPrint` the failure (use `package:mind/Logger.dart` — `logPrint` is already used in `BciDeviceManager`).

  Subscriptions to set up (store them as `late final` or nullable `StreamSubscription`s in private fields so `dispose()` can cancel them):
  - `manager.stateStream` → `BciStateChanged`
  - `manager.discoveredDevicesStream` → `BciDevicesDiscovered`
  - `manager.signalQualityStream` → `BciSignalQualityUpdated`
  - `manager.calibrationStream` → `BciCalibrationEventReceived`
  - `manager.batteryStream` → `BciBatteryUpdated`

  Public surface:
  - `Stream<BciNotifierEvent> get stream` — `_subject.stream`.
  - `BciConnectionState get currentState` — delegates to `manager.state`.
  - `List<BciDeviceInfo> get discoveredDevices` — delegates to `manager.discoveredDevices`.
  - `List<String> get knownSerials` — delegates to `manager.cachedSerials()` (already exposed in `BciDeviceManager`; no change needed there).
  - `Future<void> startScan()` → `manager.startScan()`.
  - `Future<void> connectDevice(String serial)` → `manager.connectDevice(serial)`.
  - `Future<void> startCalibration()` → `manager.startCalibration()`.
  - `Future<void> disconnect()` → `manager.disconnect()`.
  - `Future<void> dispose()` — cancel all subscriptions, close the subject, and `await manager.dispose()`.

  Notes:
  - Do NOT seed the `BehaviorSubject` with an initial event — emissions begin when underlying streams fire. (A late subscriber to a `BehaviorSubject` will still receive the last value once one is published.)
  - Do NOT add any module-specific behaviour here — this notifier is a passive translator only (RULES.md: domain notifier stays pure).

- [x] **Task 3: Wire `BciNotifier` into `App`** (depends on Task 2)
  Files: `lib/Core/App.dart`
  Add wiring inside `App.initialize()` after `SharedPreferences` is obtained (after the `final prefs = await SharedPreferences.getInstance();` line) so the repository can synchronously read its cache. Follow `App.dart`'s style rules (single-line initializer calls, no trailing commas — see the file header comment).

  Required edits:
  1. Add imports for `BciDevicesGrpcApi`, `BciDeviceRepository`, `NeiryBciProvider`, `BciDeviceManager`, `BciNotifier` from `package:mind/Bci/...`.
  2. Add a `final BciNotifier bciNotifier;` field on `App`.
  3. Add `required this.bciNotifier,` to the private `App._({...})` constructor.
  4. Inside `initialize()`, after `prefs` is loaded, append (each line single-line, no trailing commas):
     - `final bciDevicesApi = BciDevicesGrpcApi(grpcClient.bciDevicesService);`
     - `final bciRepository = BciDeviceRepository(api: bciDevicesApi, prefs: prefs);`
     - `final bciProvider = NeiryBciProvider();`
     - `final bciDeviceManager = BciDeviceManager(provider: bciProvider, repository: bciRepository);`
     - `final bciNotifier = BciNotifier(manager: bciDeviceManager);`
     - `unawaited(bciRepository.fetchKnownSerials().catchError((Object e) { return <String>[]; }));` (fire-and-forget cache warm; swallow errors so startup never fails on a missing network — match the `unawaited(... .catchError(...))` pattern already used for `DeviceRepository.ping()` and `registerDevice` in `BciDeviceManager`).
  5. Pass `bciNotifier: bciNotifier,` into the `App._(...)` invocation (keep the existing trailing-comma style of that block).

  Note on task spec: the milestone description's `BciDevicesGrpcApi(grpcClient.channel)` is a typo — `BciDevicesGrpcApi` takes a `BciDevicesServiceClient`, which is exposed as `grpcClient.bciDevicesService`. Use that.

  Do not touch `BciDeviceManager` — `cachedSerials()` is already exposed there.
