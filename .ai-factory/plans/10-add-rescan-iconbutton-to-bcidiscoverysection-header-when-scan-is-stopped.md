# Plan: Add rescan IconButton to BciDiscoverySection header when scan is stopped

## Context
Give the user a recovery control when BLE scanning times out with no device found, so they can restart discovery without closing and reopening the screen.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Add rescan control

- [x] **Task 1: Add rescan IconButton to discovery section header**
  Files: `packages/bci_module/lib/src/BciPairing/Views/BciDiscoverySection.dart`
  Add the import `import '../Models/BciPairingStage.dart';` to the import block (it is needed directly to reference `BciPairingStage.discovery`; today the enum is only reached transitively via `BciPairingState`).
  In `build()`, replace the existing header line `BciSectionHeader(title: l10n.bciPairingNearbyDevices),` (line 90) with a `Row` containing an `Expanded(child: BciSectionHeader(title: l10n.bciPairingNearbyDevices))` and a conditional `IconButton`:
  ```dart
  Row(
    children: [
      Expanded(child: BciSectionHeader(title: l10n.bciPairingNearbyDevices)),
      if (!state.isScanning && state.stage == BciPairingStage.discovery)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(bciPairingViewModelProvider.notifier).onRescan(),
          ),
        ),
    ],
  ),
  ```
  The button must be visible only when `!state.isScanning && state.stage == BciPairingStage.discovery` (scan stopped, no device connected). It stays hidden while scanning (the `LinearProgressIndicator` signals activity) and through the impedance / calibrating / ready stages.
  Do NOT touch the ViewModel, Service, or domain — `onRescan()` already exists on `BciPairingViewModel` and calls `service.startScan()`. The `state` variable is already read via `ref.watch(bciPairingViewModelProvider)` earlier in `build()`; reuse it.
