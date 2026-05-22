# Plan: Implement `BciPairingService` + `BciPairingCoordinator`

## Context

Build the two concrete implementations that bridge the BCI domain (`BciNotifier` in `lib/Bci/`) to the `bci_module` package: a stateless `BciPairingService` that derives a rolling `BciPairingState` from `BciNotifierEvent`s via RxDart `scan`, and a `BciPairingCoordinator` that closes the pairing screen via GoRouter. These complete the wiring contract required by the next milestone (`BciModule.dart` + `App.dart` + `router.dart`).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Service

- [x] **Task 1: Create `BciPairingService` (stateless reducer over `BciNotifier.stream`)**
  Files: `lib/BciModule/BciPairingService.dart` (new)

  Create the directory `lib/BciModule/` (it does not exist yet) and add a new file `BciPairingService.dart`.

  **Class shape** — mirrors the stateless pattern used by `lib/BreathModule/BreathSessionListService.dart` (constructor stores notifier, no fields beyond it, no `StreamController`, no `StreamSubscription`, no `dispose()`). Per `.ai-factory/RULES.md`: the service must be stateless; `observeChanges()` must return a derived stream directly from `bciNotifier.stream`; Riverpod manages the subscription lifecycle.

  ```dart
  class BciPairingService implements IBciPairingService {
    final BciNotifier bciNotifier;
    BciPairingService({required this.bciNotifier});
    ...
  }
  ```

  **`observeChanges()`** — derive rolling state via RxDart `scan`:
  ```dart
  @override
  Stream<BciPairingServiceEvent> observeChanges() {
    return bciNotifier.stream
        .scan<BciPairingState>(
          (acc, event, _) => _reduce(acc, event),
          BciPairingState.initial(),
        )
        .map((state) => BciPairingStateUpdated(state));
  }
  ```
  Import `rxdart/rxdart.dart` for the `scan` extension on `Stream`.

  **Load-bearing assumption — `BehaviorSubject` replay.** `BciNotifier._subject` is a `BehaviorSubject<BciNotifierEvent>` which caches only the **single most recent event**, not the latest event of each variant. If the manager has already emitted multiple slice events (e.g. `BciStateChanged → BciDevicesDiscovered → BciSignalQualityUpdated`) before the pairing screen subscribes, the new subscriber only replays the most recent one. The plan relies on `BciPairingViewModel.initState()` calling `service.startScan()` on mount to trigger fresh emissions of connection state and discovered devices; do not attempt to derive initial state from history. Add a one-line comment above `observeChanges()` noting this assumption so future maintainers don't switch to a `ReplaySubject`-style assumption.

  **`_reduce(BciPairingState acc, BciNotifierEvent event) → BciPairingState`** — pure function. Use a **`switch (event)` statement** over the sealed `BciNotifierEvent` (not chained `if (event is ...)`) so the Dart compiler enforces exhaustiveness over the variant set — mirrors the pattern used in `BreathSessionListService._mapEvent`. Branches:

  - `BciStateChanged(:final state)` — translate `BciConnectionState` → `BciPairingStage` and update transient flags. Extract the mapping into a private `BciPairingStage _mapStage(BciConnectionState)` helper to keep `_reduce` readable.

    **Important — `copyWith` semantics for nullable fields.** `BciPairingState.copyWith` only uses the `_undefined` sentinel for `calibration`, `batteryPercent`, and `errorMessage`. The fields `channels` and `devices` are plain `List? channels` / `List? devices` with bodies like `channels ?? this.channels`, so **passing `null` is a no-op** (it preserves the existing list). To "clear" these lists you MUST pass an empty const list, not `null`.

    Branches:
    - `BciConnectionState.disconnected` → `stage: discovery`, `isScanning: false`, `isConnecting: false`, **clear `calibration` and `channels`** (and clear `errorMessage` so a stale error from a prior session doesn't leak). Keep `devices` and `batteryPercent` as-is — disconnect is a transient transition; the discovered-device list and last-known battery remain useful UX context (the next `BciDevicesDiscovered` / `BciBatteryUpdated` will refresh them). Code:
      ```dart
      acc.copyWith(
        stage: BciPairingStage.discovery,
        isScanning: false,
        isConnecting: false,
        calibration: null,                        // cleared via _undefined sentinel
        channels: const <BciChannelQualityDTO>[], // MUST be empty list — null is a no-op
        errorMessage: null,                       // cleared via _undefined sentinel
      )
      ```
    - `BciConnectionState.scanning` → `stage: discovery`, `isScanning: true`, `isConnecting: false`, `errorMessage: null` (clear stale error on transition).
    - `BciConnectionState.connecting` → `stage: discovery`, `isScanning: false`, `isConnecting: true`, `errorMessage: null`.
    - `BciConnectionState.impedance` → `stage: impedance`, `isScanning: false`, `isConnecting: false`, `errorMessage: null`.
    - `BciConnectionState.calibrating` → `stage: calibrating`, `isScanning: false`, `isConnecting: false`, `errorMessage: null`.
    - `BciConnectionState.ready` → `stage: ready`, `isScanning: false`, `isConnecting: false`, `errorMessage: null`.

    **Stance on `errorMessage` clearing:** clear it on every non-error `BciStateChanged` branch above so the UI doesn't show stale error text alongside a fresh "connecting" / "scanning" state. Error text is only re-populated by `BciError` or `BciCalibrationFailed`. Add a one-line comment in `_reduce` above the `BciStateChanged` branch noting this stance.

  - `BciDevicesDiscovered(:final devices)` — map each `BciDeviceInfo` to `BciScannedDeviceDTO`:
    ```dart
    final known = bciNotifier.knownSerials.toSet();
    final dtos = devices
        .map((d) => BciScannedDeviceDTO(
              serial: d.serial,
              name: d.name,
              isKnown: known.contains(d.serial),
            ))
        .toList(growable: false);
    return acc.copyWith(devices: dtos);
    ```

  - `BciSignalQualityUpdated(:final channels)` — map each `BciChannelQuality` to `BciChannelQualityDTO` via a private `BciSignalQuality _mapLevel(BciSignalLevel)` helper (`green → good`, `yellow → fair`, `red → poor`):
    ```dart
    final dtos = channels
        .map((c) => BciChannelQualityDTO(
              channelName: c.channelName,
              quality: _mapLevel(c.level),
            ))
        .toList(growable: false);
    return acc.copyWith(channels: dtos);
    ```

  - `BciCalibrationEventReceived(:final event)` — switch over the sealed `BciCalibrationEvent`:
    - `BciCalibrationStageFinished(:final stage)`:
      ```dart
      return acc.copyWith(
        calibration: BciCalibrationProgressDTO(
          stagesCompleted: stage,
          isComplete: acc.calibration?.isComplete ?? false,
        ),
      );
      ```
    - `BciCalibrationCompleted()`:
      ```dart
      return acc.copyWith(
        calibration: BciCalibrationProgressDTO(
          stagesCompleted: acc.calibration?.stagesCompleted ?? 0,
          isComplete: true,
        ),
      );
      ```
    - `BciCalibrationFailed(:final reason)` — clear `calibration` and surface the failure reason:
      ```dart
      return acc.copyWith(calibration: null, errorMessage: reason);
      ```
      Note: `BciPairingState.copyWith` uses an `_undefined` sentinel for `calibration` and `errorMessage`, so passing `null` correctly clears `calibration` and the `reason` string correctly populates `errorMessage`.

  - `BciBatteryUpdated(:final percent)` — `return acc.copyWith(batteryPercent: percent);`

  - `BciError(:final message)` — `return acc.copyWith(errorMessage: message);`

  **Command methods** — fire-and-forget delegations to `BciNotifier`. The `IBciPairingService` interface declares them as `void`, while `BciNotifier` returns `Future<void>`; wrap each call in `unawaited(...)` (import `dart:async`) so we don't drop futures silently:
  ```dart
  @override
  void startScan() => unawaited(bciNotifier.startScan());

  @override
  void connectDevice(String serial) => unawaited(bciNotifier.connectDevice(serial));

  @override
  void startCalibration() => unawaited(bciNotifier.startCalibration());

  @override
  void disconnect() => unawaited(bciNotifier.disconnect());
  ```

  **Imports** required at the top of the file:
  - `dart:async` (for `unawaited`)
  - `package:rxdart/rxdart.dart` (for `scan`)
  - `package:bci_module/bci_module.dart` (`IBciPairingService`, `BciPairingServiceEvent`, `BciPairingStateUpdated`, `BciPairingState`, `BciPairingStage`, `BciScannedDeviceDTO`, `BciChannelQualityDTO`, `BciSignalQuality`, `BciCalibrationProgressDTO`)
  - `package:mind/Bci/BciNotifier.dart`
  - `package:mind/Bci/Models/BciNotifierEvent.dart`
  - `package:mind/Bci/Models/BciConnectionState.dart`
  - `package:mind/Bci/Models/BciCalibrationEvent.dart`
  - `package:mind/Bci/Models/BciChannelQuality.dart` (for `BciSignalLevel`)

### Phase 2: Coordinator

- [x] **Task 2: Create `BciPairingCoordinator`**
  Files: `lib/BciModule/BciPairingCoordinator.dart` (new)

  Minimal implementation mirroring the shape of `lib/BreathModule/BreathSessionCoordinator.dart`'s `dismiss()` method:

  ```dart
  import 'package:flutter/widgets.dart';
  import 'package:go_router/go_router.dart';
  import 'package:bci_module/bci_module.dart' show IBciPairingCoordinator;

  class BciPairingCoordinator implements IBciPairingCoordinator {
    final BuildContext context;

    BciPairingCoordinator(this.context);

    @override
    void close() {
      if (!context.mounted) return;
      context.pop();
    }
  }
  ```

  The `context.mounted` guard matches existing coordinator code (`BreathSessionCoordinator.dismiss`) and prevents a `pop` on a torn-down route.
