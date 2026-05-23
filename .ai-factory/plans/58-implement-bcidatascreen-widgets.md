# Plan: Implement BciDataScreen + widgets

## Context
Build the BCI data presentation screen and its supporting widgets inside `packages/bci_module`. The screen renders a header with battery + impedance dots, a heart-rate readout, and two animated bar groups (Emotions, EEG); when the device is disconnected it shows a centered empty state with a "Connect" button that opens pairing. Service/coordinator/app wiring are out of scope (separate roadmap tasks 129 and 131).

The shared-folder reorg described in `.ai-factory/notes/24-bci-data-screen.md` (`shared/BciChannelQualityDTO.dart`) is **explicitly deferred**: `BciDataState` already imports `BciChannelQualityDTO` from `BciPairing/Models/`, and `BciSectionHeader` will be reused via a relative import from `BciPairing/Views/`. Moving these into a `shared/` folder is out of scope for this plan and can be addressed as a follow-up cleanup if desired.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Localization

- [x] **Task 1: Add BCI data l10n keys (EN + RU) and regenerate**
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`, `packages/mind_l10n/lib/l10n/app_localizations.dart`, `packages/mind_l10n/lib/l10n/app_localizations_en.dart`, `packages/mind_l10n/lib/l10n/app_localizations_ru.dart`
  Append the following keys to both ARB files after the existing `bciOpenSettings` entry:
  - `bciFocus` — EN `"Focus"` / RU `"Фокус"`
  - `bciCognitiveLoad` — EN `"Cognitive load"` / RU `"Нагрузка"`
  - `bciRelaxation` — EN `"Relaxation"` / RU `"Расслабление"`
  - `bciCognitiveControl` — EN `"Cognitive control"` / RU `"Контроль"`
  - `bciSelfControl` — EN `"Self control"` / RU `"Самоконтроль"`
  - `bciHeartRate` — EN `"Heart rate"` / RU `"Пульс"` (label for the row, not a unit)
  - `bciBpm` — EN `"BPM"` / RU `"уд/мин"` (unit appended to the numeric value)
  - `bciEegBands` — EN `"EEG bands"` / RU `"ЭЭГ полосы"`
  - `bciEmotionalStates` — EN `"Emotional states"` / RU `"Состояния"`
  - `bciNotConnectedMessage` — EN `"Device not connected"` / RU `"Устройство не подключено"`
  - `bciConnectButton` — EN `"Connect"` / RU `"Подключить"`

  Regenerate the Dart localizations from `packages/mind_l10n/` using `/usr/local/bin/flutter gen-l10n` (absolute path per the global user rule). Verify the new getters appear in `app_localizations.dart`, `app_localizations_en.dart`, and `app_localizations_ru.dart`. Run `/usr/local/bin/flutter analyze` from the package to confirm regenerated files are clean.

### Phase 2: ViewModel coordinator entry points

- [x] **Task 2: Add `onConnectPressed` and `onHeaderTap` methods to `BciDataViewModel`**
  Files: `packages/bci_module/lib/src/BciData/BciDataViewModel.dart`
  Add two methods to the existing `BciDataViewModel` class that both delegate to the coordinator:
  ```dart
  void onConnectPressed() => coordinator.openPairing();
  void onHeaderTap() => coordinator.openPairing();
  ```
  The existing `final IBciDataCoordinator coordinator;` field stays as-is (it is already accessible to the class). Do **not** expose the coordinator through any new public getter or method that returns the instance itself — only these intent-named callbacks.

### Phase 3: Reusable widgets

(Both widgets live in `packages/bci_module/lib/src/BciData/Views/`. This directory does **not** exist yet — create it as part of Task 3. Mirror the structure of `BciPairing/Views/`.)

- [x] **Task 3: Create `BciMetricBar` reusable widget** (depends on Task 1)
  Files: `packages/bci_module/lib/src/BciData/Views/BciMetricBar.dart` (new directory + new file)
  Stateless widget with required `double? value` (expected range 0..1, clamped defensively), `Color color`, `String label`. Renders a fixed-width vertical container (~36dp wide, ~120dp max bar height) containing:
  - A bottom-aligned bar drawn as `AnimatedContainer` (duration `Duration(milliseconds: 400)`, curve `Curves.easeOut`) whose height = `maxBarHeight * (value ?? 0).clamp(0.0, 1.0)`. Bar opacity is `0.3` when `value == null`, otherwise `1.0`. Background color is `color`.
  - Below the bar: `label` text centered with `Theme.of(context).textTheme.labelSmall`.
  Not exported from `bci_module.dart` (package-internal use only).

- [x] **Task 4: Create `BciDataHeader` widget** (depends on Task 1)
  Files: `packages/bci_module/lib/src/BciData/Views/BciDataHeader.dart`
  Public-by-file-name (Dart lacks subpackage privacy) `ConsumerWidget` named `BciDataHeader` — **not** exported from `bci_module.dart`, used only by `BciDataScreen`. Reads `state = ref.watch(bciDataViewModelProvider)` and `vm = ref.read(bciDataViewModelProvider.notifier)`; calls `vm.onHeaderTap()` directly from a `GestureDetector` wrapping the full-width row (no `VoidCallback` constructor parameter — the widget owns the provider read).

  Layout (full-width `Padding(symmetric(horizontal: 4, vertical: 4))` matching `_BciPairingHeader`):
  - Left: battery icon (`Icons.battery_full`, size 16) + `SizedBox(width: 4)` + percent text (`'${state.batteryPercent}%'` when non-null, else `'--'`), wrapped in `Opacity(opacity: (state.isConnected && state.batteryPercent != null) ? 1.0 : 0.3, ...)` — the disconnected header is visually uniform (battery greyed out even if a stale value lingers).
  - `Spacer()`.
  - Right: impedance mini-grid — `Row(mainAxisSize: MainAxisSize.min)` of 8dp circle `Container`s (one per `BciChannelQualityDTO` in `state.channels`, separated by 4dp `SizedBox`es). Color mapped via a top-level helper `Color _impedanceColor(BciSignalQuality q)`: `good → Color(0xFFA4F792)`, `fair → Color(0xFFF8F08D)`, `poor → Color(0xFFF88D8D)`. When `!state.isConnected || state.channels.isEmpty`, render at least 4 placeholder grey dots and wrap the row in `Opacity(opacity: 0.3, ...)` — mirrors the `BciImpedanceSection` placeholder behaviour.

### Phase 4: Screen assembly

- [x] **Task 5: Implement `BciDataScreen`** (depends on Tasks 2, 3, 4)
  Files: `packages/bci_module/lib/src/BciData/BciDataScreen.dart`
  `ConsumerWidget` named `BciDataScreen` with `static const String name = 'bci_data'` and `static const String path = '/$name'`. In `build()`:
  ```dart
  final state = ref.watch(bciDataViewModelProvider);
  final vm = ref.read(bciDataViewModelProvider.notifier);
  final l10n = AppLocalizations.of(context)!;
  ```
  Import `AppLocalizations` from `package:mind_l10n/mind_l10n.dart` (same as `BciPairingScreen`).

  Layout: `Scaffold(body: SafeArea(child: Column(children: [const BciDataHeader(), Expanded(child: body)])))` where `body` is:
  - When `!state.isConnected`: `Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.bluetooth_disabled, size: 64), SizedBox(height: 16), Text(l10n.bciNotConnectedMessage), SizedBox(height: 24), FilledButton(onPressed: vm.onConnectPressed, child: Text(l10n.bciConnectButton))]))`.
  - When `state.isConnected`: `SingleChildScrollView` with `Padding(EdgeInsets.symmetric(horizontal: 16, vertical: 16))` + `Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...])`:
    1. **Heart-rate row:** `Opacity(opacity: state.heartRate != null ? 1.0 : 0.3, child: Row(children: [Icon(Icons.favorite, color: Color(0xFFF88D8D)), SizedBox(width: 8), Text(l10n.bciHeartRate, style: textTheme.bodyMedium), SizedBox(width: 12), Text(state.heartRate?.toString() ?? '--', style: textTheme.titleLarge), SizedBox(width: 4), Text(l10n.bciBpm, style: textTheme.bodySmall)]))`. The label (`bciHeartRate`) is separated from the numeric value, and the unit comes from the new `bciBpm` key — never concatenated as `'$value $bciHeartRate'`.
    2. `SizedBox(height: 24)`.
    3. Section header for emotions: reuse `BciSectionHeader(title: l10n.bciEmotionalStates)` via relative import `../BciPairing/Views/BciSectionHeader.dart` (cross-feature reuse is intentional; the shared-folder reorg is deferred per the Context section).
    4. `Padding(EdgeInsets.symmetric(horizontal: 16))` wrapping `Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [...])` of five `BciMetricBar`s:
       - `attention` → color `Color(0xFFC88DF8)`, label `l10n.bciFocus`
       - `cognitiveLoad` → color `Color(0xFFA1BFF6)`, label `l10n.bciCognitiveLoad`
       - `relaxation` → color `Color(0xFFA4F792)`, label `l10n.bciRelaxation`
       - `cognitiveControl` → color `Color(0xFFF8C88D)`, label `l10n.bciCognitiveControl`
       - `selfControl` → color `Color(0xFFF88DB8)`, label `l10n.bciSelfControl`
       Values come from `state.emotions?.attention` etc. (the DTO is null when no event has arrived yet — pass `null` straight through, the bar handles it).
    5. `SizedBox(height: 24)`.
    6. `BciSectionHeader(title: l10n.bciEegBands)`.
    7. `Padding(symmetric(horizontal: 16))` wrapping `Row(spaceEvenly, children: [...])` of five `BciMetricBar`s:
       - `delta` → `Color(0xFF8DD6F8)`, label `'Delta'`
       - `theta` → `Color(0xFFB48DF8)`, label `'Theta'`
       - `alpha` → `Color(0xFFF8F08D)`, label `'Alpha'`
       - `smr` → `Color(0xFF8DF8E4)`, label `'SMR'`
       - `beta` → `Color(0xFFF8B08D)`, label `'Beta'`
       Band names are conventional Greek letters / acronyms and are intentionally **not** localized (matches `.ai-factory/notes/24-bci-data-screen.md`).
    8. `SizedBox(height: 16)` trailing.

- [x] **Task 6: Export `BciDataScreen` from package barrel** (depends on Task 5)
  Files: `packages/bci_module/lib/bci_module.dart`
  Add `export 'src/BciData/BciDataScreen.dart';` under the existing `// Screens` section, immediately after the `BciPairingScreen` export. `BciMetricBar` and `BciDataHeader` are **not** exported — they are package-internal implementation details.

<!-- orchestrator-sessions
planner: fb2e4b15-44fe-4cf2-939f-d85fd313a475
implementer: 91d8a90a-628d-47bb-a7aa-b556dcd7573d
-->
