# BCI Data Screen

## Overview

Full-screen BCI biometric display. Header shows battery + impedance mini-grid (any tap → BCI pairing screen). Body shows heart rate and two bar groups: high-level EmotionsClassifier states (5 bars) and raw NfbClassifier EEG bands (5 bars). All values 0–1, animated vertical bars.

Navigation: HomeScreen BCI tile → BciDataScreen → header tap → BciPairingScreen.

## Architecture path

Follows the same layered pattern as BciPairing. New screen goes inside the existing `packages/bci_module` package as `BciData/`.

```
NeiryBciProvider          (neiry_kit classifiers → domain streams)
  └── IBciDeviceProvider  (extended with nfbStream, cardioStream, emotionsStream)
BciDeviceManager          (delegates new streams)
BciNotifier               (emits BciNfbUpdated, BciCardioUpdated, BciEmotionsUpdated)
BciDataService            (maps BciNotifier → IBciDataService events)
BciDataViewModel          (Riverpod Notifier<BciDataState>)
BciDataScreen             (header + heart rate + bars)
```

## Data sources and colors

### EmotionsClassifier → EmotionsStates
Displayed as primary bar group.

| Field | Label (EN / RU) | Hex |
|---|---|---|
| `attention` | Focus / Фокус | `#c88df8` |
| `cognitiveLoad` | Cognitive load / Нагрузка | `#a1bff6` |
| `relaxation` | Relaxation / Расслабление | `#a4f792` |
| `cognitiveControl` | Cognitive control / Контроль | `#f8c88d` |
| `selfControl` | Self control / Самоконтроль | `#f88db8` |

### NfbClassifier → NfbUserState
Displayed as secondary bar group (smaller, labelled by band name).

| Field | Label | Hex |
|---|---|---|
| `delta` | Delta | `#8dd6f8` |
| `theta` | Theta | `#b48df8` |
| `alpha` | Alpha | `#f8f08d` |
| `smr` | SMR | `#8df8e4` |
| `beta` | Beta | `#f8b08d` |

### CardioClassifier → CardioData
Heart rate (BPM). Show only when `metricsAvailable == true && !hasArtifacts`. Display `--` while waiting.

## Classifier lifecycle in NeiryBciProvider

Classifiers are instantiated after `connect()` succeeds (after `_device!.start()`) and disposed on `disconnect()` / `dispose()`. Three classifiers are created:

```dart
NfbClassifier? _nfbClassifier;
CardioClassifier? _cardioClassifier;
EmotionsClassifier? _emotionsClassifier;
```

After `await _device!.start()` in `connect()`:
```dart
_nfbClassifier = NfbClassifier(_device!);
_cardioClassifier = CardioClassifier(_device!);
_emotionsClassifier = EmotionsClassifier(_device!);
```

Subscribe in `_subscribeDeviceStreams()`:
```dart
_nfbSub = _nfbClassifier!.stateStream.listen(_onNfbState, onError: ...);
_cardioSub = _cardioClassifier!.stateStream.listen(_onCardioState, onError: ...);
_emotionsSub = _emotionsClassifier!.stateStream.listen(_onEmotionsState, onError: ...);
```

Cancel subs and dispose classifiers in `_cancelDeviceSubscriptions()` (called by both `disconnect()` and `_doDispose()`).

## Domain models (lib/Bci/Models/)

### BciNfbData
```dart
class BciNfbData {
  final double? delta, theta, alpha, smr, beta; // all 0–1, null if unavailable
}
```
Mapped from `NfbUserState` directly (fields have same names).

### BciCardioData
```dart
class BciCardioData {
  final double heartRate;
  final bool metricsAvailable;
  final bool hasArtifacts;
}
```

### BciEmotionsData
```dart
class BciEmotionsData {
  final double? attention, relaxation, cognitiveLoad, cognitiveControl, selfControl; // all 0–1
}
```
Mapped from `EmotionsStates`.

## IBciDeviceProvider additions

```dart
Stream<BciNfbData> get nfbStream;
Stream<BciCardioData> get cardioStream;
Stream<BciEmotionsData> get emotionsStream;
```

## BciNotifierEvent additions (lib/Bci/Models/BciNotifierEvent.dart)

```dart
class BciNfbUpdated extends BciNotifierEvent {
  final BciNfbData data;
  BciNfbUpdated(this.data);
}
class BciCardioUpdated extends BciNotifierEvent {
  final BciCardioData data;
  BciCardioUpdated(this.data);
}
class BciEmotionsUpdated extends BciNotifierEvent {
  final BciEmotionsData data;
  BciEmotionsUpdated(this.data);
}
```

BciDeviceManager exposes the three streams by delegation to provider.
BciNotifier subscribes to all three and emits the events above.

## Module boundary types (packages/bci_module/lib/src/BciData/)

### BciChannelQualityDTO — shared location

`BciChannelQualityDTO` is currently in `packages/bci_module/lib/src/BciPairing/Models/`. `BciDataState` also needs it. Move it to `packages/bci_module/lib/src/shared/BciChannelQualityDTO.dart` and update the import in `BciPairingState`. Both screens import from `shared/`.

### BciDataState
```dart
class BciDataState {
  final int? heartRate;           // null = no valid reading yet (see mapping rule below)
  final BciEmotionsDTO? emotions;
  final BciNfbDTO? nfb;
  final int? batteryPercent;      // null → header shows "--"
  final List<BciChannelQualityDTO> channels;
  final bool isConnected;
  static BciDataState initial();
}
```

**`heartRate` mapping rule** (applied in `BciDataService` when handling `BciCardioUpdated`):
```dart
heartRate = (data.metricsAvailable && !data.hasArtifacts)
    ? data.heartRate.round()
    : null;
```
`null` means "no valid reading" — UI shows `--`. The flags `metricsAvailable` and `hasArtifacts` are intentionally dropped after this conversion; they are transport details and must not leak into the DTO.

**`isConnected` mapping rule** (applied when handling `BciStateChanged`):
```dart
isConnected = state == BciConnectionState.impedance
           || state == BciConnectionState.calibrating
           || state == BciConnectionState.ready;
```
`disconnected`, `scanning`, `connecting`, and `bluetoothPermissionDenied` → `false`. `connecting` is not connected yet — the device is not usable.

**`batteryPercent` in header:** when `null`, the battery widget shows `--` (same style as heart rate placeholder, same 0.3 opacity).

### BciEmotionsDTO
```dart
class BciEmotionsDTO {
  final double? attention, cognitiveLoad, relaxation, cognitiveControl, selfControl;
}
```

### BciNfbDTO
```dart
class BciNfbDTO {
  final double? delta, theta, alpha, smr, beta;
}
```

### IBciDataService
```dart
sealed class BciDataEvent {}
class BciDataStateUpdated extends BciDataEvent {
  final BciDataState state;
}

abstract class IBciDataService {
  Stream<BciDataEvent> get events;
}
```

### IBciDataCoordinator
```dart
abstract class IBciDataCoordinator {
  void openPairing();
}
```

## BciDataViewModel

`NotifierProvider<BciDataViewModel, BciDataState>`. Subscribes to `service.events` in `build()`. Updates state on each `BciDataStateUpdated`.

## BciDataScreen layout

```
┌──────────────────────────────────────────────────────┐
│ [  🔋 42%  ● ● ● ]                        [GestureDetector → openPairing]
├──────────────────────────────────────────────────────┤
│                                                      │
│   ♥  72 BPM                                          │
│                                                      │
│   ── Emotional states ──────────────────             │
│   [█ focus] [█ cog.load] [█ relax] [█ cog.ctrl] [█ self] │
│                                                      │
│   ── EEG bands ─────────────────────────             │
│   [█ δ] [█ θ] [█ α] [█ smr] [█ β]                   │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### Disconnected empty state

When `!state.isConnected`, render a centered column instead of the data content (header stays visible):

```
[icon: bluetooth_disabled or device icon]
"Device not connected"  ← l10n key: bciNotConnectedMessage
[Filled button: "Connect"]  ← calls coordinator.openPairing()
```

Button and message use existing theme styles. No bars, no heart rate display.

When `state.isConnected` flips to `true` (user paired and came back), the ViewModel rebuilds and the data view appears — no navigation needed.

Add l10n keys: `bciNotConnectedMessage` (EN: "Device not connected" / RU: "Устройство не подключено"), `bciConnectButton` (EN: "Connect" / RU: "Подключить").

### Header (BciDataHeader)

Private `ConsumerWidget`. `GestureDetector` wrapping full-width row: battery icon + percent on left, impedance mini-grid on right. Tap calls `coordinator.openPairing()`.

**Impedance mini-grid:** same color mapping as `BciChannelQualityDTO.quality` (good=green `#a4f792`, fair=yellow `#f8f08d`, poor=red `#f88d8d`). Dots are ~8dp circles, arranged in a tight grid matching channel count. When disconnected (channels empty) all dots render at 0.3 opacity.

### Animated bars (BciMetricBar)

Reusable widget: `BciMetricBar({required double? value, required Color color, required String label})`. Value `null` → bar at 0 height with 0.3 opacity. Animated via `AnimatedContainer` or `TweenAnimationBuilder` with ~400ms ease-out.

## BciDataService (lib/BciModule/BciDataService.dart)

Subscribes to `bciNotifier.stream`, maintains running `BciDataState` via `.scan()` or explicit accumulation, maps events to state updates, emits `BciDataStateUpdated`. Same pattern as `BciPairingService`.

Handles: `BciNfbUpdated`, `BciCardioUpdated`, `BciEmotionsUpdated`, `BciStateChanged` (for isConnected, batteryPercent passthrough), `BciSignalQualityUpdated` (channels), `BciBatteryUpdated`.

## Wiring (lib/BciModule/BciModule.dart)

Add `static Widget buildDataScreen(BuildContext context)` alongside existing `buildPairing`.

## Route (lib/router.dart)

`BciDataScreen.path = '/bci_data'`.

Add `GoRoute(path: BciDataScreen.path, builder: (c, s) => BciModule.buildDataScreen(c))`.

## HomeScreen navigation

`HomeCoordinator` currently calls `vm.onComingSoonTap()` for the BCI tile. Replace with navigation to `BciDataScreen.path`.

## l10n keys to add

| Key | EN | RU |
|---|---|---|
| `bciFocus` | Focus | Фокус |
| `bciCognitiveLoad` | Cognitive load | Нагрузка |
| `bciRelaxation` | Relaxation | Расслабление |
| `bciCognitiveControl` | Cognitive control | Контроль |
| `bciSelfControl` | Self control | Самоконтроль |
| `bciHeartRate` | Heart rate | Пульс |
| `bciEegBands` | EEG bands | ЭЭГ полосы |
| `bciEmotionalStates` | Emotional states | Состояния |
| `bciNotConnectedMessage` | Device not connected | Устройство не подключено |
| `bciConnectButton` | Connect | Подключить |
