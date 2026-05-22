# Plan: Define module boundary types in `packages/bci_module/`

## Context
Create the DTOs, state model, and Service/Coordinator interfaces that form the `bci_module` package boundary for the BCI pairing flow. These types let the upcoming `BciPairingViewModel`, `BciPairingScreen`, and the concrete `BciPairingService`/`BciPairingCoordinator` (which will live in `lib/BciModule/`) compile against a stable contract — domain types (`BciDeviceInfo`, `BciChannelQuality`, `BciCalibrationEvent`, `BciConnectionState`) must not leak into the package.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: DTOs and state

Tasks 1–4 have no inter-dependencies — Phase 1's commit boundary is what groups them. Task 5 depends on all of them.

- [x] **Task 1: Add `BciPairingStage` enum**
  Files: `packages/bci_module/lib/src/BciPairing/Models/BciPairingStage.dart`
  Define a top-level Dart `enum BciPairingStage { discovery, impedance, calibrating, ready }`. Plain enum, no extensions, no constructors. This is the package-local mirror of the relevant subset of `BciConnectionState` exposed to the UI (the domain enum from `lib/Bci/Models/BciConnectionState.dart` is not imported here — translation happens in the concrete `BciPairingService`).
  **Mapping note (for the concrete service in the next milestone):** domain `BciConnectionState.disconnected/scanning/connecting` all collapse to `BciPairingStage.discovery`; the granularity that the UI needs (spinner placement, list shimmer) is carried by the `isScanning`/`isConnecting` booleans on `BciPairingState`. `impedance/calibrating/ready` map 1:1.

- [x] **Task 2: Add `BciScannedDeviceDTO`** (no dependencies)
  Files: `packages/bci_module/lib/src/BciPairing/Models/BciScannedDeviceDTO.dart`
  Immutable value class with `final String serial`, `final String name`, `final bool isKnown`. Const constructor with `required` named parameters. Follow the style of `packages/breath_module/lib/src/BreathSession/Models/BreathSessionDTO.dart` (const ctor, no equality overrides unless other DTOs in the same package use them — `BreathSessionDTO` doesn't, so we don't either).

- [x] **Task 3: Add `BciSignalQuality` enum + `BciChannelQualityDTO`** (no dependencies)
  Files: `packages/bci_module/lib/src/BciPairing/Models/BciChannelQualityDTO.dart`
  Declare `enum BciSignalQuality { good, fair, poor }` and `class BciChannelQualityDTO` with `final String channelName`, `final BciSignalQuality quality`. Const constructor with `required` named parameters. Both symbols live in the same file (parallel to how related sealed events live together in the breath module).

- [x] **Task 4: Add `BciCalibrationProgressDTO`** (no dependencies)
  Files: `packages/bci_module/lib/src/BciPairing/Models/BciCalibrationProgressDTO.dart`
  Immutable value class with `final int stagesCompleted` and `final bool isComplete`. Const constructor with `required` named parameters.
  Document invariants in a `///` comment on the class:
  > `stagesCompleted` is in the range 0–4 (one entry per stage emitted by domain `BciCalibrationStageFinished`).
  > `isComplete` corresponds to domain `BciCalibrationCompleted` and is authoritative; it MAY be `true` while `stagesCompleted < 4` if the domain emits completion early. Consumers should treat `isComplete` as the terminal signal — do not infer completion from `stagesCompleted == 4` alone.

- [x] **Task 5: Add `BciPairingState`** (depends on Tasks 1–4)
  Files: `packages/bci_module/lib/src/BciPairing/Models/BciPairingState.dart`
  Immutable class with the following final fields (in this order): `BciPairingStage stage`, `List<BciScannedDeviceDTO> devices`, `bool isScanning`, `bool isConnecting`, `List<BciChannelQualityDTO> channels`, `BciCalibrationProgressDTO? calibration`, `int? batteryPercent`, `String? errorMessage`. Const constructor with `required` named parameters for non-nullable fields; nullable fields default to `null`.
  Add a `static BciPairingState initial()` returning `const BciPairingState(stage: BciPairingStage.discovery, devices: [], isScanning: false, isConnecting: false, channels: [])` (a `static` method per the milestone spec — keep this shape rather than switching to a `factory` or a `static const` field).
  Include a `copyWith({...})` returning a new instance — needed by the concrete service's pure reducer (see Task 6) when emitting incremental updates.
  Document on the `calibration` field that consumers should treat `calibration == null` as "no active calibration data" (e.g. before calibration has started, or after a failure has cleared it), not as "calibration is in stage 0".
  **Contract note (for the concrete service in the next milestone):** on calibration failure (`BciCalibrationFailed(reason)`), the reducer clears `calibration` (sets it to `null`), drops `stage` back to `impedance`, and populates `errorMessage` with the failure reason — failures are surfaced via `errorMessage`, not via a flag on `BciCalibrationProgressDTO`.

### Phase 2: Service + Coordinator interfaces

- [x] **Task 6: Add `IBciPairingService` + `BciPairingServiceEvent`** (depends on Task 5)
  Files: `packages/bci_module/lib/src/BciPairing/IBciPairingService.dart`
  Declare a sealed event hierarchy: `sealed class BciPairingServiceEvent { const BciPairingServiceEvent(); }` with one variant `final class BciPairingStateUpdated extends BciPairingServiceEvent { final BciPairingState state; const BciPairingStateUpdated(this.state); }` (single-variant today, sealed so future events extend cleanly — same approach as `BciNotifierEvent` in `lib/Bci/Models/BciNotifierEvent.dart`). Declare `abstract class IBciPairingService` with:
  - `Stream<BciPairingServiceEvent> observeChanges();`
  - `void startScan();`
  - `void connectDevice(String serial);`
  - `void startCalibration();`
  - `void disconnect();`

  **Naming rationale:** `observeChanges()` (a method, not a getter) matches the sibling `IBreathSessionListService.observeChanges()` / `IBreathSessionService.observeSession(id)` convention. Command methods return `void` per the milestone spec — the concrete service is fire-and-forget, mirroring `BciNotifier` delegation.

  **Implementer guidance for the next milestone (RULES.md Rule #1 compliance):** `BciNotifier` emits *incremental* events (`BciStateChanged`, `BciDevicesDiscovered`, `BciSignalQualityUpdated`, `BciBatteryUpdated`, `BciCalibrationEventReceived`, `BciError`), but `BciPairingStateUpdated` carries the *rolling* `BciPairingState` snapshot. The concrete service MUST implement `observeChanges()` statelessly by deriving the rolling state from `bciNotifier.stream` using RxDart `scan` with a pure reducer:

  ```dart
  Stream<BciPairingServiceEvent> observeChanges() => bciNotifier.stream
      .scan<BciPairingState>(
        (acc, event, _) => _applyEvent(acc, event),
        BciPairingState.initial(),
      )
      .map(BciPairingStateUpdated.new);
  ```

  RxDart 0.28's `scan` takes exactly two arguments (accumulator, seed) and does **not** emit the seed on subscribe — the first emission happens after the first upstream event. If the UI needs an immediate "initial" emission, the next-milestone implementer can prepend `.startWith(BciPairingStateUpdated(BciPairingState.initial()))` after the `.map(...)`. No `StreamController`, no `StreamSubscription`, no `dispose()` — Riverpod manages the subscription lifecycle via `ref.onDispose` in the ViewModel. `BciPairingState.copyWith` (Task 5) exists for the reducer to produce new accumulator instances.

  Imports: only the local DTO files — no `lib/Bci/` imports.

- [x] **Task 7: Add `IBciPairingCoordinator`**
  Files: `packages/bci_module/lib/src/BciPairing/IBciPairingCoordinator.dart`
  `abstract class IBciPairingCoordinator { void close(); }`. Single-action coordinator — the pairing screen has only one navigation exit, so the interface stays minimal even though `IBreathSessionCoordinator` (the closest sibling) carries three methods for its richer nav surface.

### Phase 3: Public exports

- [x] **Task 8: Export all new symbols from the barrel** (depends on Tasks 1–7)
  Files: `packages/bci_module/lib/bci_module.dart`
  Under the existing comment headers, add exports following the same grouping used by `packages/breath_module/lib/breath_module.dart`:
  - Under `// Service + Coordinator interfaces`: `export 'src/BciPairing/IBciPairingService.dart';` and `export 'src/BciPairing/IBciPairingCoordinator.dart';`
  - Under `// Other public symbols`: `export 'src/BciPairing/Models/BciPairingStage.dart';`, `export 'src/BciPairing/Models/BciScannedDeviceDTO.dart';`, `export 'src/BciPairing/Models/BciChannelQualityDTO.dart';`, `export 'src/BciPairing/Models/BciCalibrationProgressDTO.dart';`, `export 'src/BciPairing/Models/BciPairingState.dart';`
  Verify the package compiles by running `/usr/local/bin/flutter pub get` then `/usr/local/bin/flutter analyze packages/bci_module` from the repo root.

## Commit Plan
- **Commit 1** (after tasks 1–5): "Add BciPairing DTOs and state model to bci_module"
- **Commit 2** (after tasks 6–8): "Add BciPairing Service/Coordinator interfaces and export barrel"
