# Plan: Implement `BciDataService` + `BciDataCoordinator`

## Context
Bridge the domain layer (`BciNotifier`) to the `bci_module` package by implementing the concrete `IBciDataService` (reduces `BciNotifierEvent` stream into `BciDataState`) and `IBciDataCoordinator` (navigates to the BCI pairing screen). This is the final domain↔module wiring piece before `BciDataScreen` can be mounted in the app.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Concrete service & coordinator

- [x] **Task 1: Implement `BciDataCoordinator`**
  Files: `lib/BciModule/BciDataCoordinator.dart`
  Create a new file mirroring `lib/BciModule/BciPairingCoordinator.dart`. Class `BciDataCoordinator implements IBciDataCoordinator` with a final `BuildContext context` field set via constructor. Implement `void openPairing()` that early-returns when `!context.mounted` and otherwise calls `context.push(BciPairingScreen.path)`. Imports: `package:flutter/widgets.dart`, `package:go_router/go_router.dart`, `package:bci_module/bci_module.dart` (for `IBciDataCoordinator` and `BciPairingScreen`).

- [x] **Task 2: Implement `BciDataService`**
  Files: `lib/BciModule/BciDataService.dart`
  Create a new file modelled after `lib/BciModule/BciPairingService.dart`:
  - Class `BciDataService implements IBciDataService` with `final BciNotifier bciNotifier` injected via constructor.
  - Override `Stream<BciDataEvent> get events` returning `bciNotifier.stream.scan<BciDataState>((acc, event, _) => _reduce(acc, event), BciDataState.initial()).map((state) => BciDataStateUpdated(state))`.
  - Private `BciDataState _reduce(BciDataState acc, BciNotifierEvent event)` exhaustive switch over the sealed `BciNotifierEvent`:
    - `BciNfbUpdated(:final data)` → `acc.copyWith(nfb: BciNfbDTO(delta: data.delta, theta: data.theta, alpha: data.alpha, smr: data.smr, beta: data.beta))`.
    - `BciCardioUpdated(:final data)` → `acc.copyWith(heartRate: (data.metricsAvailable && !data.hasArtifacts) ? data.heartRate.round() : null)` (see `notes/24-bci-data-screen.md` mapping rule — flags are intentionally dropped after this conversion).
    - `BciEmotionsUpdated(:final data)` → `acc.copyWith(emotions: BciEmotionsDTO(attention: data.attention, cognitiveLoad: data.cognitiveLoad, relaxation: data.relaxation, cognitiveControl: data.cognitiveControl, selfControl: data.selfControl))`.
    - `BciBatteryUpdated(:final percent)` → `acc.copyWith(batteryPercent: percent)`.
    - `BciSignalQualityUpdated(:final channels)` → map each `BciChannelQuality` to `BciChannelQualityDTO(channelName: c.channelName, quality: _mapLevel(c.level))` using the same `BciSignalLevel → BciSignalQuality` mapping as `BciPairingService` (green→good, yellow→fair, red→poor). Re-implement `_mapLevel` locally — do not depend on `BciPairingService`.
    - `BciStateChanged(:final state)` → `acc.copyWith(isConnected: state == BciConnectionState.impedance || state == BciConnectionState.calibrating || state == BciConnectionState.ready)`. All other `BciConnectionState` values (`disconnected`, `scanning`, `connecting`, `bluetoothPermissionDenied`) → `false`.
    - `BciDevicesDiscovered()`, `BciCalibrationEventReceived()`, `BciError()` → return `acc` unchanged (data screen does not consume these).
  - Imports: `package:rxdart/rxdart.dart` for `.scan()`, `package:bci_module/bci_module.dart` for `IBciDataService`, `BciDataEvent`, `BciDataStateUpdated`, `BciDataState`, `BciNfbDTO`, `BciEmotionsDTO`, `BciChannelQualityDTO`, `BciSignalQuality`, and `package:mind/Bci/BciNotifier.dart` + the `Models/*` files for the event sealed class and connection state.

## Notes for the implementer
- `BciNotifier.stream` is a `BehaviorSubject` — new subscribers replay only the single most-recent event (same caveat as `BciPairingService`). Reducer must produce a sensible state when events arrive in any order; `BciDataState.initial()` already handles missing fields via nullables / empty list / `isConnected:false`.
- Do not modify `BciPairingService` — the pairing reducer already ignores `BciNfbUpdated`/`BciCardioUpdated`/`BciEmotionsUpdated` and works alongside the new data service.
- Wiring into `BciModule.buildDataScreen(...)` and adding the route is intentionally out of scope — handled by the next roadmap milestone.

<!-- orchestrator-sessions
planner: e3c04bd2-cb8e-470f-856a-7a9dab6528ec
implementer: 8ba4d219-9330-4cfc-ae5e-737e17bda84f
-->
